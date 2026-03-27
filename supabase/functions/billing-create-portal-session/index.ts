import { requireAuthenticatedContext } from "../_shared/auth.ts";
import {
  getCustomerByUserId,
  updateCustomer,
} from "../_shared/billing-data.ts";
import { corsPreflightResponse, errorResponse, jsonResponse } from "../_shared/http.ts";
import { createRequestId, logFunctionEvent } from "../_shared/log.ts";
import { resolveAppReturnUrl } from "../_shared/return-url.ts";
import { createBillingProvider } from "../_shared/stripe-provider.ts";

function isMissingStripeCustomerError(error: unknown) {
  return error instanceof Error && /No such customer/i.test(error.message);
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
    let customer = await getCustomerByUserId(context.serviceClient, context.user.id);

    if (!customer) {
      const { error: ensureBillingError } = await context.serviceClient.rpc(
        "ensure_default_billing_for_user",
        {
          target_user_id: context.user.id,
          target_email: context.user.email ?? "",
          target_full_name:
            typeof context.user.user_metadata.full_name === "string"
              ? context.user.user_metadata.full_name
              : "",
        },
      );

      if (ensureBillingError) {
        throw new Error(ensureBillingError.message);
      }

      customer = await getCustomerByUserId(context.serviceClient, context.user.id);
    }

    if (!customer) {
      throw new Error("Customer record was not provisioned for this user.");
    }

    const provider = createBillingProvider();
    let gatewayCustomerId = customer.gateway_customer_id;

    async function provisionStripeCustomer() {
      const createdCustomer = await provider.createCustomer({
        email: customer.billing_email,
        fullName: customer.full_name,
        taxDocument: customer.tax_document,
      });
      gatewayCustomerId = createdCustomer.gatewayCustomerId;
      customer = {
        ...customer,
        gateway_customer_id: gatewayCustomerId,
        metadata: {
          ...(customer.metadata ?? {}),
          provider_customer: createdCustomer.rawPayload,
        },
      };

      await updateCustomer(context.serviceClient, customer.id, {
        gateway_customer_id: gatewayCustomerId,
        metadata: customer.metadata,
      });
    }

    if (!gatewayCustomerId) {
      await provisionStripeCustomer();
    }

    if (!gatewayCustomerId) {
      throw new Error("Stripe customer ID is not available for this account.");
    }

    const returnUrl = resolveAppReturnUrl(
      request,
      body.returnUrl,
      Deno.env.get("STRIPE_PORTAL_RETURN_URL") ?? Deno.env.get("APP_BILLING_RETURN_URL"),
    );

    let session;
    try {
      session = await provider.createPortalSession({
        gatewayCustomerId,
        returnUrl,
      });
    } catch (error) {
      if (!isMissingStripeCustomerError(error)) {
        throw error;
      }

      await provisionStripeCustomer();
      session = await provider.createPortalSession({
        gatewayCustomerId,
        returnUrl,
      });
    }

    return jsonResponse({
      url: session.url,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    logFunctionEvent({
      area: "billing-portal",
      event: "portal_session_failed",
      level: "error",
      requestId,
      metadata: {
        message,
      },
    });
    return errorResponse(message, 500);
  }
});
