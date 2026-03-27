import {
  getCustomerById,
  getPlanById,
  getSubscriptionById,
  getSubscriptionByExternalReference,
  getSubscriptionByGatewayId,
  markBillingEventProcessed,
  recordBillingEvent,
  syncSubscriptionFromProvider,
  updateSubscriptionRecord,
  upsertPayment,
} from "../_shared/billing-data.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { createRequestId, logFunctionEvent } from "../_shared/log.ts";
import { createBillingProvider } from "../_shared/stripe-provider.ts";
import { sendSubscriptionConfirmationEmail } from "../_shared/subscription-email.ts";
import { validateStripeWebhook } from "../_shared/stripe-webhook.ts";
import { createServiceRoleClient } from "../_shared/supabase.ts";

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function asString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

Deno.serve(async (request) => {
  const requestId = createRequestId(request);
  if (request.method !== "POST") {
    return errorResponse("Method not allowed.", 405);
  }

  try {
    const rawBody = await request.text();
    const isValidSignature = await validateStripeWebhook(request, rawBody);
    if (!isValidSignature) {
      return errorResponse("Invalid Stripe webhook signature.", 401);
    }

    const payload = toRecord(JSON.parse(rawBody));
    const eventData = toRecord(payload.data);
    const eventObject = toRecord(eventData.object);
    const eventType = typeof payload.type === "string" ? payload.type : "unknown";
    const eventId = typeof payload.id === "string"
      ? payload.id
      : `${eventType}:${String(eventObject.id ?? "unknown")}`;

    const serviceClient = createServiceRoleClient();
    const shouldProcess = await recordBillingEvent(
      serviceClient,
      eventId,
      eventType,
      payload,
    );

    if (!shouldProcess) {
      logFunctionEvent({
        area: "billing-webhook",
        event: "duplicate_event_ignored",
        requestId,
        metadata: {
          eventId,
          eventType,
        },
      });
      return jsonResponse({ ok: true, duplicate: true });
    }

    const provider = createBillingProvider();
    let matchedSubscription = null;
    const providerResult = await provider.handleWebhook({
      topic: eventType,
      action: null,
      resourceId: typeof eventObject.id === "string" ? eventObject.id : null,
      payload,
    });

    if (providerResult.subscription) {
      const subscription =
        (providerResult.subscription.gatewaySubscriptionId
          ? await getSubscriptionByGatewayId(
              serviceClient,
              providerResult.subscription.gatewaySubscriptionId,
            )
          : null) ??
        (providerResult.subscription.externalReference
          ? await getSubscriptionByExternalReference(
              serviceClient,
              providerResult.subscription.externalReference,
            )
          : null);

      if (subscription) {
        matchedSubscription = subscription;
        await syncSubscriptionFromProvider(
          serviceClient,
          subscription,
          providerResult.subscription,
        );
      }
    }

    if (providerResult.payment) {
      const paymentSubscription =
        providerResult.payment.subscriptionGatewayId
          ? await getSubscriptionByGatewayId(
              serviceClient,
              providerResult.payment.subscriptionGatewayId,
            )
          : null;
      const externalReferenceSubscription =
        !paymentSubscription && providerResult.payment.externalReference
          ? await getSubscriptionByExternalReference(
              serviceClient,
              providerResult.payment.externalReference,
            )
          : null;
      const subscription = paymentSubscription ?? externalReferenceSubscription;

      if (subscription) {
        matchedSubscription = subscription;
        await upsertPayment(
          serviceClient,
          subscription.user_id,
          subscription.id,
          providerResult.payment,
        );
      }
    }

    await maybeSendInitialSubscriptionEmail(
      serviceClient,
      eventType,
      providerResult.payment?.rawPayload ?? null,
      matchedSubscription,
    );

    await maybeCancelReplacedSubscription(
      serviceClient,
      provider,
      eventType,
      providerResult.payment?.rawPayload ?? null,
      matchedSubscription,
    );

    await markBillingEventProcessed(serviceClient, eventId);
    logFunctionEvent({
      area: "billing-webhook",
      event: "event_processed",
      requestId,
      metadata: {
        eventId,
        eventType,
      },
    });
    return jsonResponse({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    logFunctionEvent({
      area: "billing-webhook",
      event: "event_processing_failed",
      level: "error",
      requestId,
      metadata: {
        message,
      },
    });
    return errorResponse(message, 500);
  }
});

async function maybeSendInitialSubscriptionEmail(
  serviceClient: ReturnType<typeof createServiceRoleClient>,
  eventType: string,
  paymentPayload: Record<string, unknown> | null,
  subscription: Awaited<ReturnType<typeof getSubscriptionByGatewayId>>,
) {
  if (eventType !== "invoice.paid" || !paymentPayload || !subscription) {
    return;
  }

  const billingReason = asString(paymentPayload.billing_reason);
  if (billingReason !== "subscription_create") {
    return;
  }

  const metadata = toRecord(subscription.metadata);
  if (asString(metadata.initial_confirmation_email_sent_at)) {
    return;
  }

  const [plan, customer] = await Promise.all([
    getPlanById(serviceClient, subscription.plan_id),
    subscription.customer_id ? getCustomerById(serviceClient, subscription.customer_id) : Promise.resolve(null),
  ]);

  if (!plan || !customer) {
    return;
  }

  try {
    await sendSubscriptionConfirmationEmail({
      customer,
      plan,
      subscription,
    });

    await updateSubscriptionRecord(serviceClient, subscription.id, {
      metadata: {
        ...metadata,
        initial_confirmation_email_sent_at: new Date().toISOString(),
      },
      updated_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Failed to send subscription confirmation email", error);
  }
}

async function maybeCancelReplacedSubscription(
  serviceClient: ReturnType<typeof createServiceRoleClient>,
  provider: ReturnType<typeof createBillingProvider>,
  eventType: string,
  paymentPayload: Record<string, unknown> | null,
  subscription: Awaited<ReturnType<typeof getSubscriptionByGatewayId>>,
) {
  if (eventType !== "invoice.paid" || !paymentPayload || !subscription) {
    return;
  }

  const billingReason = asString(paymentPayload.billing_reason);
  if (billingReason !== "subscription_create") {
    return;
  }

  const metadata = toRecord(subscription.metadata);
  const replacedSubscriptionId = asString(metadata.replaces_subscription_id);
  if (!replacedSubscriptionId) {
    return;
  }

  const replacedSubscription = await getSubscriptionById(
    serviceClient,
    replacedSubscriptionId,
  );

  if (!replacedSubscription || replacedSubscription.cancel_at_period_end) {
    return;
  }

  let updatedMetadata = {
    ...(replacedSubscription.metadata ?? {}),
    replaced_by_subscription_id: subscription.id,
    replaced_by_plan_id: subscription.plan_id,
    replaced_at: new Date().toISOString(),
  };

  if (replacedSubscription.gateway_subscription_id) {
    try {
      const canceledSubscription = await provider.cancelSubscription(
        replacedSubscription.gateway_subscription_id,
      );

      await syncSubscriptionFromProvider(
        serviceClient,
        replacedSubscription,
        canceledSubscription,
      );
    } catch (error) {
      console.error("Failed to schedule cancellation for replaced subscription", error);
    }
  }

  await updateSubscriptionRecord(serviceClient, replacedSubscription.id, {
    cancel_at_period_end: true,
    metadata: updatedMetadata,
    updated_at: new Date().toISOString(),
  });
}
