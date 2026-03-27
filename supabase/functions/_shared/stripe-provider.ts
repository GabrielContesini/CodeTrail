import type {
  BillingCheckoutUiMode,
  BillingProvider,
  InternalSubscriptionStatus,
  ProviderCustomerInput,
  ProviderCustomerResult,
  ProviderPaymentResult,
  ProviderPortalSessionInput,
  ProviderPortalSessionResult,
  ProviderSubscriptionInput,
  ProviderSubscriptionResult,
  ProviderWebhookEvent,
  ProviderWebhookResult,
} from "./billing-provider.ts";

const STRIPE_API_BASE = "https://api.stripe.com";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function asString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function asNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function toIsoFromUnix(value: unknown): string | null {
  const timestamp = asNumber(value);
  if (timestamp == null) {
    return null;
  }
  return new Date(timestamp * 1000).toISOString();
}

function mapSubscriptionStatus(status: string | null): InternalSubscriptionStatus {
  switch ((status ?? "").toLowerCase()) {
    case "trialing":
      return "trialing";
    case "active":
      return "active";
    case "past_due":
      return "past_due";
    case "unpaid":
      return "unpaid";
    case "canceled":
      return "canceled";
    case "incomplete":
      return "incomplete";
    case "incomplete_expired":
      return "expired";
    case "paused":
      return "unpaid";
    default:
      return "incomplete";
  }
}

function appendFormValue(
  params: URLSearchParams,
  key: string,
  value: unknown,
): void {
  if (value == null) {
    return;
  }

  if (Array.isArray(value)) {
    value.forEach((entry, index) => {
      appendFormValue(params, `${key}[${index}]`, entry);
    });
    return;
  }

  if (typeof value === "object") {
    for (const [childKey, childValue] of Object.entries(
      value as Record<string, unknown>,
    )) {
      appendFormValue(params, `${key}[${childKey}]`, childValue);
    }
    return;
  }

  if (typeof value === "boolean") {
    params.append(key, value ? "true" : "false");
    return;
  }

  params.append(key, String(value));
}

function formEncode(body: Record<string, unknown>): URLSearchParams {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(body)) {
    appendFormValue(params, key, value);
  }
  return params;
}

function resolveStringId(value: unknown): string | null {
  if (typeof value === "string") {
    return value;
  }
  if (value && typeof value === "object") {
    return asString((value as Record<string, unknown>).id);
  }
  return null;
}

function resolveReturnUrl(value: string | null | undefined): string {
  const returnUrl = value ?? Deno.env.get("APP_BILLING_RETURN_URL");
  if (!returnUrl) {
    throw new Error("Missing APP_BILLING_RETURN_URL for Stripe checkout.");
  }
  return returnUrl;
}

function sanitizeCheckoutPayload(payload: Record<string, unknown>) {
  const nextPayload = { ...payload };
  delete nextPayload.client_secret;
  return nextPayload;
}

export class StripeBillingProvider implements BillingProvider {
  constructor(private readonly secretKey = requireEnv("STRIPE_SECRET_KEY")) {}

  readonly name = "stripe";

  async createCustomer(input: ProviderCustomerInput): Promise<ProviderCustomerResult> {
    const response = await this.#request("/v1/customers", {
      method: "POST",
      body: {
        email: input.email,
        name: input.fullName,
        metadata: {
          source: "codetrail",
        },
      },
    });

    return {
      gatewayCustomerId: asString(response.id),
      rawPayload: response,
    };
  }

  async createSubscription(input: ProviderSubscriptionInput): Promise<ProviderSubscriptionResult> {
    return this.#createCheckoutSession(input);
  }

  async createPaymentLink(input: ProviderSubscriptionInput): Promise<ProviderSubscriptionResult> {
    return this.#createCheckoutSession(input);
  }

  async createPortalSession(
    input: ProviderPortalSessionInput,
  ): Promise<ProviderPortalSessionResult> {
    const response = await this.#request("/v1/billing_portal/sessions", {
      method: "POST",
      body: {
        customer: input.gatewayCustomerId,
        return_url: input.returnUrl,
      },
    });

    const url = asString(response.url);
    if (!url) {
      throw new Error("Stripe customer portal did not return a URL.");
    }

    return {
      url,
      rawPayload: response,
    };
  }

  async cancelSubscription(gatewaySubscriptionId: string): Promise<ProviderSubscriptionResult> {
    const response = await this.#request(`/v1/subscriptions/${gatewaySubscriptionId}`, {
      method: "POST",
      body: {
        cancel_at_period_end: true,
      },
    });

    return this.#normalizeSubscription(response);
  }

  async getSubscription(gatewaySubscriptionId: string): Promise<ProviderSubscriptionResult> {
    const response = await this.#request(`/v1/subscriptions/${gatewaySubscriptionId}`, {
      method: "GET",
    });
    return this.#normalizeSubscription(response);
  }

  async syncSubscriptionStatus(gatewaySubscriptionId: string): Promise<ProviderSubscriptionResult> {
    return this.getSubscription(gatewaySubscriptionId);
  }

  async getPayment(gatewayPaymentId: string): Promise<ProviderPaymentResult> {
    const response = await this.#request(
      `/v1/invoices/${gatewayPaymentId}?expand[]=charge`,
      { method: "GET" },
    );
    return this.#normalizeInvoice(response);
  }

  async handleWebhook(event: ProviderWebhookEvent): Promise<ProviderWebhookResult> {
    const eventType = asString(event.payload.type) ?? event.topic;
    const object = toRecord(toRecord(event.payload.data).object);

    if (eventType === "checkout.session.completed") {
      const subscriptionId = resolveStringId(object.subscription);
      if (!subscriptionId) {
        return { subscription: null, payment: null };
      }
      return {
        subscription: await this.getSubscription(subscriptionId),
        payment: null,
      };
    }

    if (eventType.startsWith("customer.subscription.")) {
      return {
        subscription: this.#normalizeSubscription(object),
        payment: null,
      };
    }

    if (
      eventType === "invoice.paid" ||
      eventType === "invoice.payment_failed" ||
      eventType === "invoice.finalized"
    ) {
      const payment = this.#normalizeInvoice(object);
      const subscriptionId = payment.subscriptionGatewayId;
      return {
        subscription: subscriptionId
          ? await this.getSubscription(subscriptionId)
          : null,
        payment,
      };
    }

    return { subscription: null, payment: null };
  }

  async #createCheckoutSession(
    input: ProviderSubscriptionInput,
  ): Promise<ProviderSubscriptionResult> {
    const uiMode: BillingCheckoutUiMode = input.uiMode ?? "hosted";
    const returnUrl = resolveReturnUrl(input.backUrl);
    const successUrl = `${returnUrl}${returnUrl.includes("?") ? "&" : "?"}billing=success&session_id={CHECKOUT_SESSION_ID}`;
    const cancelUrl = `${returnUrl}${returnUrl.includes("?") ? "&" : "?"}billing=cancel`;
    const metadata = toRecord(input.plan.metadata);
    const stripePriceId = asString(metadata.stripe_price_id);

    const lineItems = stripePriceId
      ? [
          {
            price: stripePriceId,
            quantity: 1,
          },
        ]
      : [
          {
            quantity: 1,
            price_data: {
              currency: input.plan.currency.toLowerCase(),
              unit_amount: input.plan.price_cents,
              recurring: {
                interval: input.plan.interval,
              },
              product_data: {
                name: input.plan.name,
                description: input.plan.description,
              },
            },
          },
        ];

    const response = await this.#request("/v1/checkout/sessions", {
      method: "POST",
      body: {
        mode: "subscription",
        payment_method_types: ["card"],
        ...(uiMode === "embedded"
          ? {
              ui_mode: "embedded",
              return_url: returnUrl,
              redirect_on_completion: "if_required",
            }
          : {
              success_url: successUrl,
              cancel_url: cancelUrl,
            }),
        customer: input.customer.gateway_customer_id,
        client_reference_id: input.externalReference,
        line_items: lineItems,
        metadata: {
          internal_subscription_id: input.internalSubscriptionId,
          plan_code: input.plan.code,
        },
        subscription_data: {
          metadata: {
            internal_subscription_id: input.internalSubscriptionId,
            plan_code: input.plan.code,
          },
        },
      },
    });

    return {
      gatewaySubscriptionId: resolveStringId(response.subscription),
      externalReference:
        asString(response.client_reference_id) ?? input.externalReference,
      gatewayCustomerId: resolveStringId(response.customer),
      status: "incomplete",
      statusDetail: asString(response.status) ?? "checkout_open",
      uiMode,
      checkoutUrl: uiMode === "hosted" ? asString(response.url) : null,
      clientSecret: uiMode === "embedded" ? asString(response.client_secret) : null,
      managementUrl: null,
      startedAt: null,
      currentPeriodStart: null,
      currentPeriodEnd: null,
      trialEndsAt: null,
      cancelAtPeriodEnd: false,
      rawPayload: sanitizeCheckoutPayload(response),
    };
  }

  async #request(
    path: string,
    options: {
      method: "GET" | "POST";
      body?: Record<string, unknown>;
    },
  ): Promise<Record<string, unknown>> {
    const headers = new Headers({
      Authorization: `Bearer ${this.secretKey}`,
    });

    let body: string | undefined;
    if (options.body) {
      headers.set("Content-Type", "application/x-www-form-urlencoded");
      headers.set("Idempotency-Key", crypto.randomUUID());
      body = formEncode(options.body).toString();
    }

    const response = await fetch(`${STRIPE_API_BASE}${path}`, {
      method: options.method,
      headers,
      body,
    });

    const json = await response.json().catch(() => ({}));
    if (!response.ok) {
      const errorPayload = toRecord(json);
      const errorObject = toRecord(errorPayload.error);
      const errorMessage =
        asString(errorObject.message) ??
        asString(errorPayload.message) ??
        `Stripe request failed with status ${response.status}.`;
      throw new Error(errorMessage);
    }

    return toRecord(json);
  }

  #normalizeSubscription(payload: Record<string, unknown>): ProviderSubscriptionResult {
    return {
      gatewaySubscriptionId: asString(payload.id),
      externalReference:
        asString(toRecord(payload.metadata).internal_subscription_id) ??
        asString(toRecord(payload.metadata).external_reference),
      gatewayCustomerId: resolveStringId(payload.customer),
      status: mapSubscriptionStatus(asString(payload.status)),
      statusDetail: asString(payload.status),
      uiMode: "hosted",
      checkoutUrl: null,
      clientSecret: null,
      managementUrl: null,
      startedAt: toIsoFromUnix(payload.start_date),
      currentPeriodStart: toIsoFromUnix(payload.current_period_start),
      currentPeriodEnd: toIsoFromUnix(payload.current_period_end),
      trialEndsAt: toIsoFromUnix(payload.trial_end),
      cancelAtPeriodEnd: Boolean(payload.cancel_at_period_end),
      rawPayload: payload,
    };
  }

  #normalizeInvoice(payload: Record<string, unknown>): ProviderPaymentResult {
    const charge = toRecord(payload.charge);
    const statusTransitions = toRecord(payload.status_transitions);
    const metadata = toRecord(payload.metadata);
    const amountPaid = asNumber(payload.amount_paid);
    const amountDue = asNumber(payload.amount_due);

    return {
      gatewayPaymentId: asString(payload.id) ?? "",
      externalReference:
        asString(metadata.internal_subscription_id) ??
        asString(metadata.external_reference),
      subscriptionGatewayId: resolveStringId(payload.subscription),
      amountCents: Math.round(amountPaid ?? amountDue ?? 0),
      currency: (asString(payload.currency) ?? "usd").toUpperCase(),
      status: asString(payload.status) ?? "open",
      statusDetail: asString(payload.collection_method),
      paidAt:
        toIsoFromUnix(statusTransitions.paid_at) ??
        toIsoFromUnix(payload.created),
      invoiceUrl:
        asString(payload.hosted_invoice_url) ??
        asString(payload.invoice_pdf),
      receiptUrl: asString(charge.receipt_url),
      rawPayload: payload,
    };
  }
}

export function createBillingProvider(): BillingProvider {
  const provider = Deno.env.get("BILLING_PROVIDER") ?? "stripe";
  if (provider !== "stripe") {
    throw new Error(`Unsupported billing provider: ${provider}`);
  }
  return new StripeBillingProvider();
}
