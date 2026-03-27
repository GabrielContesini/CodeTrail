export type BillingPlanCode = "free" | "pro" | "founding";
export type BillingCycle = "month" | "year";
export type BillingCheckoutUiMode = "hosted" | "embedded";
export type InternalSubscriptionStatus =
  | "trialing"
  | "active"
  | "past_due"
  | "unpaid"
  | "canceled"
  | "expired"
  | "incomplete";

export interface BillingPlanRecord {
  id: string;
  code: BillingPlanCode;
  name: string;
  description: string;
  price_cents: number;
  currency: string;
  interval: BillingCycle;
  trial_days: number;
  is_active?: boolean;
  is_public?: boolean;
  metadata: Record<string, unknown> | null;
}

export interface BillingCustomerRecord {
  id: string;
  user_id: string;
  gateway_provider: string;
  gateway_customer_id: string | null;
  billing_email: string;
  full_name: string;
  tax_document: string | null;
  metadata: Record<string, unknown> | null;
}

export interface ProviderCustomerInput {
  email: string;
  fullName: string;
  taxDocument?: string | null;
}

export interface ProviderCustomerResult {
  gatewayCustomerId: string | null;
  rawPayload: Record<string, unknown>;
}

export interface ProviderSubscriptionInput {
  internalSubscriptionId: string;
  customer: BillingCustomerRecord;
  plan: BillingPlanRecord;
  externalReference: string;
  backUrl?: string | null;
  uiMode?: BillingCheckoutUiMode;
}

export interface ProviderSubscriptionResult {
  gatewaySubscriptionId: string | null;
  externalReference: string | null;
  gatewayCustomerId: string | null;
  status: InternalSubscriptionStatus;
  statusDetail: string | null;
  uiMode: BillingCheckoutUiMode;
  checkoutUrl: string | null;
  clientSecret: string | null;
  managementUrl: string | null;
  startedAt: string | null;
  currentPeriodStart: string | null;
  currentPeriodEnd: string | null;
  trialEndsAt: string | null;
  cancelAtPeriodEnd: boolean;
  rawPayload: Record<string, unknown>;
}

export interface ProviderPortalSessionInput {
  gatewayCustomerId: string;
  returnUrl: string;
}

export interface ProviderPortalSessionResult {
  url: string;
  rawPayload: Record<string, unknown>;
}

export interface ProviderPaymentResult {
  gatewayPaymentId: string;
  externalReference: string | null;
  subscriptionGatewayId: string | null;
  amountCents: number;
  currency: string;
  status: string;
  statusDetail: string | null;
  paidAt: string | null;
  invoiceUrl: string | null;
  receiptUrl: string | null;
  rawPayload: Record<string, unknown>;
}

export interface ProviderWebhookEvent {
  topic: string;
  action: string | null;
  resourceId: string | null;
  payload: Record<string, unknown>;
}

export interface ProviderWebhookResult {
  subscription: ProviderSubscriptionResult | null;
  payment: ProviderPaymentResult | null;
}

export interface BillingProvider {
  readonly name: string;
  createCustomer(input: ProviderCustomerInput): Promise<ProviderCustomerResult>;
  createSubscription(input: ProviderSubscriptionInput): Promise<ProviderSubscriptionResult>;
  cancelSubscription(gatewaySubscriptionId: string): Promise<ProviderSubscriptionResult>;
  getSubscription(gatewaySubscriptionId: string): Promise<ProviderSubscriptionResult>;
  createPaymentLink(input: ProviderSubscriptionInput): Promise<ProviderSubscriptionResult>;
  createPortalSession(input: ProviderPortalSessionInput): Promise<ProviderPortalSessionResult>;
  handleWebhook(event: ProviderWebhookEvent): Promise<ProviderWebhookResult>;
  syncSubscriptionStatus(gatewaySubscriptionId: string): Promise<ProviderSubscriptionResult>;
  getPayment(gatewayPaymentId: string): Promise<ProviderPaymentResult>;
}
