import type {
  BillingCustomerRecord,
  BillingPlanRecord,
} from "./billing-provider.ts";
import type { BillingSubscriptionRow } from "./billing-data.ts";

const RESEND_API_BASE = "https://api.resend.com/emails";
const SUBSCRIPTION_TEMPLATE_ID =
  Deno.env.get("RESEND_SUBSCRIPTION_TEMPLATE_ID") ?? "subscription-confirmed";
const DEFAULT_FROM = "CodeTrail Suporte <onboarding@resend.dev>";
const WELCOME_SUBJECT = "Bem-vindo(a) ao CodeTrail 🚀";

export async function sendSubscriptionConfirmationEmail(input: {
  customer: BillingCustomerRecord;
  plan: BillingPlanRecord;
  subscription: BillingSubscriptionRow;
}) {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    return { skipped: true, reason: "missing_resend_api_key" };
  }

  const to = input.customer.billing_email.trim();
  if (!to) {
    return { skipped: true, reason: "missing_billing_email" };
  }

  const from = Deno.env.get("RESEND_FROM_EMAIL") ?? DEFAULT_FROM;
  const dashboardUrl = resolveDashboardUrl();
  const userName = input.customer.full_name?.trim() || "Explorer";
  const planName = input.plan.name?.trim() || "Plano premium";

  const response = await fetch(RESEND_API_BASE, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "Idempotency-Key": `subscription-confirmed:${input.subscription.id}:${input.plan.id}`,
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: WELCOME_SUBJECT,
      template: {
        id: SUBSCRIPTION_TEMPLATE_ID,
        variables: {
          user_name: userName,
          plan_name: planName,
          dashboard_url: dashboardUrl,
        },
      },
    }),
  });

  if (!response.ok) {
    const payload = await response.text().catch(() => "");
    throw new Error(payload || `Resend request failed with status ${response.status}.`);
  }

  return await response.json().catch(() => ({ ok: true }));
}

function resolveDashboardUrl() {
  const configured = Deno.env.get("APP_DASHBOARD_URL")?.trim();
  if (configured) {
    return configured;
  }

  return "https://www.codetrail.online/workspace/dashboard";
}
