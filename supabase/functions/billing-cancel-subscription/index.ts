import { requireAuthenticatedContext } from "../_shared/auth.ts";
import {
  getBillingSnapshot,
  getLatestPaidSubscription,
  syncSubscriptionFromProvider,
  updateSubscriptionRecord,
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
    const subscription = await getLatestPaidSubscription(
      context.serviceClient,
      context.user.id,
    );

    if (!subscription?.gateway_subscription_id) {
      return errorResponse("No paid subscription was found for this user.", 404);
    }

    const provider = createBillingProvider();
    try {
      const providerSubscription = await provider.cancelSubscription(
        subscription.gateway_subscription_id,
      );
      await syncSubscriptionFromProvider(
        context.serviceClient,
        subscription,
        providerSubscription,
      );
    } catch (error) {
      if (!isMissingStripeSubscriptionError(error)) {
        throw error;
      }

      await updateSubscriptionRecord(context.serviceClient, subscription.id, {
        status: "canceled",
        status_detail: "gateway_resource_missing",
        cancel_at_period_end: false,
        canceled_at: new Date().toISOString(),
        metadata: {
          ...(subscription.metadata ?? {}),
          gateway_resource_missing: true,
          gateway_resource_missing_at: new Date().toISOString(),
        },
        updated_at: new Date().toISOString(),
      });
    }

    const snapshot = await getBillingSnapshot(context.userClient);
    logFunctionEvent({
      area: "billing-cancel",
      event: "subscription_cancelled",
      requestId,
      userId: context.user.id,
      metadata: {
        status: snapshot?.subscription?.status ?? "canceled",
      },
    });
    return jsonResponse({
      snapshot,
      status: snapshot?.subscription?.status ?? "canceled",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    logFunctionEvent({
      area: "billing-cancel",
      event: "subscription_cancel_failed",
      level: "error",
      requestId,
      metadata: {
        message,
      },
    });
    return errorResponse(message, 500);
  }
});
