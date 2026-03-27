import {
  type AuthenticatedContext,
  requireAuthenticatedContext,
} from "../_shared/auth.ts";
import {
  type BillingCheckoutUiMode,
  createSubscriptionRecord,
  getBillingSnapshot,
  getCustomerByUserId,
  getLatestPaidSubscription,
  getPlanByCode,
  updateSubscriptionRecord,
  updateCustomer,
} from "../_shared/billing-data.ts";
import type { BillingPlanCode } from "../_shared/billing-provider.ts";
import { corsPreflightResponse, errorResponse, jsonResponse } from "../_shared/http.ts";
import { createRequestId, logFunctionEvent } from "../_shared/log.ts";
import { resolveAppReturnUrl } from "../_shared/return-url.ts";
import { createBillingProvider } from "../_shared/stripe-provider.ts";

async function isFoundingPlanAvailable(
  serviceClient: AuthenticatedContext["serviceClient"],
  options: {
    userId: string;
    email: string;
    planIsPublic: boolean;
  },
) {
  if (options.planIsPublic) {
    return true;
  }

  const { data: configRow, error: configError } = await serviceClient
    .from("billing_config")
    .select("founding_plan_enabled, founding_requires_allowlist")
    .limit(1)
    .maybeSingle();

  if (configError) {
    throw new Error(configError.message);
  }

  if (!configRow?.founding_plan_enabled) {
    return false;
  }

  if (!configRow.founding_requires_allowlist) {
    return true;
  }

  const { count: userMatchCount, error: userMatchError } = await serviceClient
    .from("founder_eligibility")
    .select("*", { count: "exact", head: true })
    .eq("is_eligible", true)
    .eq("user_id", options.userId);

  if (userMatchError) {
    throw new Error(userMatchError.message);
  }

  if ((userMatchCount ?? 0) > 0) {
    return true;
  }

  const normalizedEmail = options.email.trim().toLowerCase();
  if (!normalizedEmail) {
    return false;
  }

  const { count: emailMatchCount, error: emailMatchError } = await serviceClient
    .from("founder_eligibility")
    .select("*", { count: "exact", head: true })
    .eq("is_eligible", true)
    .ilike("email", normalizedEmail);

  if (emailMatchError) {
    throw new Error(emailMatchError.message);
  }

  return (emailMatchCount ?? 0) > 0;
}

function isMissingStripeCustomerError(error: unknown) {
  return error instanceof Error && /No such customer/i.test(error.message);
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function isStripeLiveModeConfigured() {
  return (Deno.env.get("STRIPE_SECRET_KEY") ?? "").startsWith("sk_live_");
}

function isLegacyStripeSubscription(
  subscription: Awaited<ReturnType<typeof getLatestPaidSubscription>>,
) {
  if (!subscription || subscription.gateway_provider !== "stripe") {
    return false;
  }

  const metadata = toRecord(subscription.metadata);
  return isStripeLiveModeConfigured() && metadata.livemode === false;
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
    const planCode = typeof body.planCode === "string"
      ? body.planCode
      : null;
    const uiMode: BillingCheckoutUiMode =
      body.uiMode === "embedded" ? "embedded" : "hosted";
    const returnUrl = resolveAppReturnUrl(
      request,
      body.returnUrl,
      Deno.env.get("APP_BILLING_RETURN_URL"),
    );

    if (!planCode || !["pro", "founding"].includes(planCode)) {
      return errorResponse("Unsupported plan code.", 422);
    }

    const plan = await getPlanByCode(
      context.serviceClient,
      planCode as BillingPlanCode,
    );

    if (planCode === "founding") {
      const foundingAvailable = await isFoundingPlanAvailable(
        context.serviceClient,
        {
          userId: context.user.id,
          email: context.user.email ?? "",
          planIsPublic: plan.is_public !== false,
        },
      );
      if (!foundingAvailable) {
        return errorResponse("Founding plan is not available for this user.", 403);
      }
    }

    const currentPaid = await getLatestPaidSubscription(
      context.serviceClient,
      context.user.id,
    );
    const currentPaidIsLegacyStripe = isLegacyStripeSubscription(currentPaid);

    const hasActivePaidSubscription =
      currentPaid &&
      ["active", "trialing", "past_due"].includes(currentPaid.status) &&
      !currentPaidIsLegacyStripe;

    if (hasActivePaidSubscription && currentPaid.plan_id === plan.id) {
      return errorResponse("This paid plan is already active for this user.", 409);
    }
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

    const replacementSubscription =
      currentPaid &&
      ["active", "trialing", "past_due"].includes(currentPaid.status) &&
      currentPaid.plan_id !== plan.id
        ? currentPaid
        : null;
    const internalSubscriptionId =
      currentPaid?.status === "incomplete" && currentPaid.plan_id === plan.id
      ? currentPaid.id
      : crypto.randomUUID();
    const externalReference =
      currentPaid?.status === "incomplete" && currentPaid.plan_id === plan.id
        ? currentPaid.external_reference ?? internalSubscriptionId
        : internalSubscriptionId;
    let providerSubscription;
    try {
      providerSubscription = await provider.createPaymentLink({
        internalSubscriptionId,
        customer: {
          ...customer,
          gateway_customer_id: gatewayCustomerId,
        },
        plan,
        externalReference,
        backUrl: returnUrl,
        uiMode,
      });
    } catch (error) {
      if (!isMissingStripeCustomerError(error)) {
        throw error;
      }

      await provisionStripeCustomer();

      providerSubscription = await provider.createPaymentLink({
        internalSubscriptionId,
        customer: {
          ...customer,
          gateway_customer_id: gatewayCustomerId,
        },
        plan,
        externalReference,
        backUrl: returnUrl,
        uiMode,
      });
    }

    if (uiMode === "embedded") {
      if (providerSubscription.clientSecret == null ||
          providerSubscription.clientSecret.length == 0) {
        throw new Error("Stripe did not return an embedded checkout client secret.");
      }
    } else if (
      providerSubscription.checkoutUrl == null ||
      providerSubscription.checkoutUrl.length == 0
    ) {
      throw new Error("Stripe did not return a checkout URL.");
    }

    const subscriptionPayload = {
      id: internalSubscriptionId,
      user_id: context.user.id,
      plan_id: plan.id,
      customer_id: customer.id,
      gateway_provider: provider.name,
      gateway_subscription_id: providerSubscription.gatewaySubscriptionId,
      external_reference: providerSubscription.externalReference ?? externalReference,
      status: providerSubscription.status,
      status_detail: providerSubscription.statusDetail,
      billing_cycle: plan.interval,
      started_at: providerSubscription.startedAt ?? new Date().toISOString(),
      current_period_start: providerSubscription.currentPeriodStart,
      current_period_end: providerSubscription.currentPeriodEnd,
      cancel_at_period_end: providerSubscription.cancelAtPeriodEnd,
      trial_ends_at: providerSubscription.trialEndsAt,
      metadata: {
        ...providerSubscription.rawPayload,
        checkout_url: providerSubscription.checkoutUrl,
        management_url: providerSubscription.managementUrl,
        return_url: returnUrl,
        replaces_subscription_id: replacementSubscription?.id ?? null,
        replaces_gateway_subscription_id: replacementSubscription?.gateway_subscription_id ?? null,
      },
    };

    const record = currentPaid?.status === "incomplete" && currentPaid.plan_id === plan.id
      ? await updateSubscriptionRecord(context.serviceClient, currentPaid.id, subscriptionPayload)
      : await createSubscriptionRecord(context.serviceClient, subscriptionPayload);

    if (providerSubscription.gatewayCustomerId && !customer.gateway_customer_id) {
      await updateCustomer(context.serviceClient, customer.id, {
        gateway_customer_id: providerSubscription.gatewayCustomerId,
      });
    }

    const snapshot = await getBillingSnapshot(context.userClient);
    logFunctionEvent({
      area: "billing-checkout",
      event: "checkout_session_created",
      requestId,
      userId: context.user.id,
      metadata: {
        planCode,
        uiMode,
      },
    });
    return jsonResponse({
      uiMode: providerSubscription.uiMode,
      checkoutUrl: providerSubscription.checkoutUrl,
      clientSecret: providerSubscription.clientSecret,
      managementUrl: providerSubscription.managementUrl,
      subscriptionId: record.id,
      snapshot,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    logFunctionEvent({
      area: "billing-checkout",
      event: "checkout_session_failed",
      level: "error",
      requestId,
      metadata: {
        message,
      },
    });
    return errorResponse(message, 500);
  }
});
