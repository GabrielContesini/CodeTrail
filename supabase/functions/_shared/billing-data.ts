import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

import type {
  BillingCustomerRecord,
  BillingPlanCode,
  BillingPlanRecord,
  ProviderPaymentResult,
  ProviderSubscriptionResult,
} from "./billing-provider.ts";

export interface BillingSubscriptionRow {
  id: string;
  user_id: string;
  plan_id: string;
  customer_id: string | null;
  gateway_provider: string;
  gateway_subscription_id: string | null;
  external_reference: string | null;
  status: string;
  status_detail: string | null;
  billing_cycle: "month" | "year";
  current_period_start: string | null;
  current_period_end: string | null;
  cancel_at_period_end: boolean;
  canceled_at: string | null;
  trial_ends_at: string | null;
  grace_until: string | null;
  metadata: Record<string, unknown> | null;
}

function getConfiguredBillingProvider(): string {
  return Deno.env.get("BILLING_PROVIDER") ?? "stripe";
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

export async function getPlanByCode(
  client: SupabaseClient,
  planCode: BillingPlanCode,
): Promise<BillingPlanRecord> {
  const { data, error } = await client
    .from("plans")
    .select("*")
    .eq("code", planCode)
    .eq("is_active", true)
    .single();

  if (error || !data) {
    throw new Error(`Plan not found for code ${planCode}.`);
  }

  return data as BillingPlanRecord;
}

export async function getCustomerByUserId(
  client: SupabaseClient,
  userId: string,
): Promise<BillingCustomerRecord | null> {
  const provider = getConfiguredBillingProvider();
  const { data, error } = await client
    .from("customers")
    .select("*")
    .eq("user_id", userId)
    .eq("gateway_provider", provider)
    .order("updated_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false })
    .limit(10);

  if (error) {
    throw new Error(error.message);
  }

  const rows = (data ?? []) as BillingCustomerRecord[];
  if (rows.length === 0) {
    return null;
  }

  const customerWithGatewayId = rows.find((row) =>
    typeof row.gateway_customer_id === "string" && row.gateway_customer_id.trim().length > 0
  );

  return customerWithGatewayId ?? rows[0];
}

export async function updateCustomer(
  client: SupabaseClient,
  customerId: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const { error } = await client
    .from("customers")
    .update(payload)
    .eq("id", customerId);

  if (error) {
    throw new Error(error.message);
  }
}

export async function createSubscriptionRecord(
  client: SupabaseClient,
  payload: Record<string, unknown>,
): Promise<BillingSubscriptionRow> {
  const { data, error } = await client
    .from("subscriptions")
    .insert(payload)
    .select("*")
    .single();

  if (error || !data) {
    throw new Error(error?.message ?? "Failed to create subscription record.");
  }

  return data as BillingSubscriptionRow;
}

export async function updateSubscriptionRecord(
  client: SupabaseClient,
  subscriptionId: string,
  payload: Record<string, unknown>,
): Promise<BillingSubscriptionRow> {
  const { data, error } = await client
    .from("subscriptions")
    .update(payload)
    .eq("id", subscriptionId)
    .select("*")
    .single();

  if (error || !data) {
    throw new Error(error?.message ?? "Failed to update subscription.");
  }

  return data as BillingSubscriptionRow;
}

export async function getLatestPaidSubscription(
  client: SupabaseClient,
  userId: string,
): Promise<BillingSubscriptionRow | null> {
  const { data: plans, error: planError } = await client
    .from("plans")
    .select("id")
    .in("code", ["pro", "founding"]);

  if (planError) {
    throw new Error(planError.message);
  }

  const planIds = (plans ?? []).map((plan) => plan.id as string);
  if (planIds.length === 0) {
    return null;
  }

  const { data, error } = await client
    .from("subscriptions")
    .select("*")
    .eq("user_id", userId)
    .in("plan_id", planIds)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data as BillingSubscriptionRow | null;
}

export async function getSubscriptionByGatewayId(
  client: SupabaseClient,
  gatewaySubscriptionId: string,
): Promise<BillingSubscriptionRow | null> {
  const { data, error } = await client
    .from("subscriptions")
    .select("*")
    .eq("gateway_subscription_id", gatewaySubscriptionId)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data as BillingSubscriptionRow | null;
}

export async function getSubscriptionByExternalReference(
  client: SupabaseClient,
  externalReference: string,
): Promise<BillingSubscriptionRow | null> {
  const { data, error } = await client
    .from("subscriptions")
    .select("*")
    .eq("external_reference", externalReference)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data as BillingSubscriptionRow | null;
}

export async function getSubscriptionById(
  client: SupabaseClient,
  subscriptionId: string,
): Promise<BillingSubscriptionRow | null> {
  const { data, error } = await client
    .from("subscriptions")
    .select("*")
    .eq("id", subscriptionId)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data as BillingSubscriptionRow | null;
}

export async function getPlanById(
  client: SupabaseClient,
  planId: string,
): Promise<BillingPlanRecord | null> {
  const { data, error } = await client
    .from("plans")
    .select("*")
    .eq("id", planId)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data as BillingPlanRecord | null;
}

export async function getCustomerById(
  client: SupabaseClient,
  customerId: string,
): Promise<BillingCustomerRecord | null> {
  const { data, error } = await client
    .from("customers")
    .select("*")
    .eq("id", customerId)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data as BillingCustomerRecord | null;
}

export async function getBillingSnapshot(userClient: SupabaseClient): Promise<Record<string, unknown>> {
  const { data, error } = await userClient.rpc("get_my_billing_snapshot");
  if (error) {
    throw new Error(error.message);
  }
  return toRecord(data);
}

export async function upsertPayment(
  client: SupabaseClient,
  userId: string,
  subscriptionId: string | null,
  payment: ProviderPaymentResult,
): Promise<void> {
  const provider = getConfiguredBillingProvider();
  const payload = {
    user_id: userId,
    subscription_id: subscriptionId,
    gateway_provider: provider,
    gateway_payment_id: payment.gatewayPaymentId,
    external_reference: payment.externalReference,
    amount_cents: payment.amountCents,
    currency: payment.currency,
    status: payment.status,
    status_detail: payment.statusDetail,
    paid_at: payment.paidAt,
    invoice_url: payment.invoiceUrl,
    receipt_url: payment.receiptUrl,
    raw_payload: payment.rawPayload,
    metadata: {},
    updated_at: new Date().toISOString(),
  };

  const { error } = await client
    .from("payments")
    .upsert(payload, {
      onConflict: "gateway_payment_id",
    });

  if (error) {
    throw new Error(error.message);
  }
}

export async function recordBillingEvent(
  client: SupabaseClient,
  eventId: string,
  eventType: string,
  payload: Record<string, unknown>,
): Promise<boolean> {
  const provider = getConfiguredBillingProvider();
  const { data: existing, error: existingError } = await client
    .from("billing_events")
    .select("id, processed")
    .eq("event_id", eventId)
    .maybeSingle();

  if (existingError) {
    throw new Error(existingError.message);
  }

  if (existing?.processed) {
    return false;
  }

  if (!existing) {
    const { error } = await client
      .from("billing_events")
      .insert({
        gateway_provider: provider,
        event_type: eventType,
        event_id: eventId,
        payload,
      });

    if (error) {
      throw new Error(error.message);
    }
  }

  return true;
}

export async function markBillingEventProcessed(
  client: SupabaseClient,
  eventId: string,
): Promise<void> {
  const { error } = await client
    .from("billing_events")
    .update({ processed: true })
    .eq("event_id", eventId);

  if (error) {
    throw new Error(error.message);
  }
}

export async function syncSubscriptionFromProvider(
  client: SupabaseClient,
  subscriptionRow: BillingSubscriptionRow,
  providerSubscription: ProviderSubscriptionResult,
): Promise<BillingSubscriptionRow> {
  const metadata = {
    ...(subscriptionRow.metadata ?? {}),
    ...(providerSubscription.rawPayload ?? {}),
    checkout_url: providerSubscription.checkoutUrl,
    management_url: providerSubscription.managementUrl,
  };

  const payload = {
    gateway_subscription_id:
      providerSubscription.gatewaySubscriptionId ?? subscriptionRow.gateway_subscription_id,
    external_reference:
      providerSubscription.externalReference ?? subscriptionRow.external_reference,
    status: providerSubscription.status,
    status_detail: providerSubscription.statusDetail,
    current_period_start:
      providerSubscription.currentPeriodStart ?? subscriptionRow.current_period_start,
    current_period_end:
      providerSubscription.currentPeriodEnd ?? subscriptionRow.current_period_end,
    cancel_at_period_end: providerSubscription.cancelAtPeriodEnd,
    canceled_at: providerSubscription.cancelAtPeriodEnd
      ? (subscriptionRow.canceled_at ?? new Date().toISOString())
      : null,
    metadata,
    updated_at: new Date().toISOString(),
  };

  return updateSubscriptionRecord(client, subscriptionRow.id, payload);
}
