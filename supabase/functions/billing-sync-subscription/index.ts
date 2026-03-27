import { requireAuthenticatedContext } from "../_shared/auth.ts";
import {
  getBillingSnapshot,
  getLatestPaidSubscription,
  getSubscriptionByGatewayId,
  syncSubscriptionFromProvider,
  updateSubscriptionRecord,
  upsertPayment,
} from "../_shared/billing-data.ts";
import { corsPreflightResponse, errorResponse, jsonResponse } from "../_shared/http.ts";
import { createRequestId, logFunctionEvent } from "../_shared/log.ts";
import { createBillingProvider } from "../_shared/stripe-provider.ts";

function isMissingStripeSubscriptionError(error: unknown) {
  return error instanceof Error && /No such subscription/i.test(error.message);
}

Deno.serve(async (request) => {
  const requestId = createRequestId(request);
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return errorResponse("Method not allowed.", 405);
  }

  try {
    const context = await requireAuthenticatedContext(request);
    const body = await request.json().catch(() => ({}));
    const gatewaySubscriptionId = typeof body.gatewaySubscriptionId === "string"
      ? body.gatewaySubscriptionId
      : null;
    const paymentId = typeof body.paymentId === "string"
      ? body.paymentId
      : null;

    let subscription = gatewaySubscriptionId
      ? await getSubscriptionByGatewayId(context.serviceClient, gatewaySubscriptionId)
      : await getLatestPaidSubscription(context.serviceClient, context.user.id);

    if (!subscription?.gateway_subscription_id) {
      const snapshot = await getBillingSnapshot(context.userClient);
      return jsonResponse({ snapshot });
    }

    const provider = createBillingProvider();
    let providerStatus = subscription.status;

    try {
      const providerSubscription = await provider.syncSubscriptionStatus(
        subscription.gateway_subscription_id,
      );
      providerStatus = providerSubscription.status;
      subscription = await syncSubscriptionFromProvider(
        context.serviceClient,
        subscription,
        providerSubscription,
      );
    } catch (error) {
      if (!isMissingStripeSubscriptionError(error)) {
        throw error;
      }

      subscription = await updateSubscriptionRecord(context.serviceClient, subscription.id, {
        status: "expired",
        status_detail: "gateway_resource_missing",
        metadata: {
          ...(subscription.metadata ?? {}),
          gateway_resource_missing: true,
          gateway_resource_missing_at: new Date().toISOString(),
        },
        updated_at: new Date().toISOString(),
      });
      providerStatus = "expired";
    }

    if (paymentId) {
      const payment = await provider.getPayment(paymentId);
      await upsertPayment(
        context.serviceClient,
        context.user.id,
        subscription.id,
        payment,
      );
    }

    const snapshot = await getBillingSnapshot(context.userClient);
    logFunctionEvent({
      area: "billing-sync",
      event: "subscription_synced",
      requestId,
      userId: context.user.id,
      metadata: {
        status: providerStatus,
      },
    });
    return jsonResponse({
      snapshot,
      status: providerStatus,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    logFunctionEvent({
      area: "billing-sync",
      event: "subscription_sync_failed",
      level: "error",
      requestId,
      metadata: {
        message,
      },
    });
    return errorResponse(message, 500);
  }
});
