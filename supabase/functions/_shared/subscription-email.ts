import type {
  BillingCustomerRecord,
  BillingPlanRecord,
} from "./billing-provider.ts";
import type { BillingSubscriptionRow } from "./billing-data.ts";

const RESEND_API_BASE = "https://api.resend.com/emails";

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

  const from = Deno.env.get("RESEND_FROM_EMAIL") ?? "CodeTrail <onboarding@resend.dev>";
  const replyTo = Deno.env.get("RESEND_REPLY_TO_EMAIL");
  const manageUrl =
    Deno.env.get("APP_BILLING_RETURN_URL") ??
    Deno.env.get("STRIPE_PORTAL_RETURN_URL") ??
    "https://codetrail.app/workspace/settings/billing";

  const customerName = input.customer.full_name?.trim() || "dev";
  const amount = formatCurrencyBrl(input.plan.price_cents);
  const billingCycle = input.plan.interval === "year" ? "anual" : "mensal";
  const renewalLabel = input.subscription.current_period_end
    ? new Date(input.subscription.current_period_end).toLocaleDateString("pt-BR")
    : null;

  const subject = `Sua assinatura ${input.plan.name} no CodeTrail esta ativa`;
  const html = [
    "<div style=\"font-family:Arial,sans-serif;background:#0b0f16;color:#f4f7fb;padding:32px;line-height:1.6;\">",
    "<div style=\"max-width:640px;margin:0 auto;border:1px solid rgba(255,255,255,0.12);background:#101722;padding:32px;\">",
    "<p style=\"margin:0 0 12px;color:#7fe3ff;font-size:12px;letter-spacing:0.18em;text-transform:uppercase;font-weight:700;\">CodeTrail Billing</p>",
    `<h1 style=\"margin:0 0 16px;font-size:28px;line-height:1.2;\">Assinatura confirmada, ${escapeHtml(customerName)}.</h1>`,
    `<p style=\"margin:0 0 18px;color:#c2cad6;\">Seu plano <strong style=\"color:#ffffff;\">${escapeHtml(input.plan.name)}</strong> ja esta ativo no CodeTrail.</p>`,
    "<div style=\"margin:24px 0;padding:20px;border:1px solid rgba(127,227,255,0.2);background:rgba(127,227,255,0.06);\">",
    `<p style=\"margin:0 0 8px;\"><strong>Valor:</strong> ${amount}</p>`,
    `<p style=\"margin:0 0 8px;\"><strong>Ciclo:</strong> ${billingCycle}</p>`,
    `<p style=\"margin:0;\"><strong>Status:</strong> ${escapeHtml(input.subscription.status)}</p>`,
    renewalLabel
      ? `<p style=\"margin:8px 0 0;\"><strong>Proxima renovacao:</strong> ${renewalLabel}</p>`
      : "",
    "</div>",
    `<p style=\"margin:0 0 24px;color:#c2cad6;\">Voce pode acompanhar sua assinatura, notas fiscais e gerenciamento do plano diretamente pelo workspace.</p>`,
    `<a href=\"${escapeHtml(manageUrl)}\" style=\"display:inline-block;padding:14px 20px;background:#7fe3ff;color:#071019;text-decoration:none;font-weight:700;\">Abrir billing</a>`,
    "<p style=\"margin:24px 0 0;color:#8b95a7;font-size:13px;\">Se voce nao reconhece esta assinatura, responda este email imediatamente.</p>",
    "</div>",
    "</div>",
  ].join("");

  const text = [
    `Assinatura confirmada, ${customerName}.`,
    "",
    `Plano: ${input.plan.name}`,
    `Valor: ${amount}`,
    `Ciclo: ${billingCycle}`,
    `Status: ${input.subscription.status}`,
    renewalLabel ? `Proxima renovacao: ${renewalLabel}` : null,
    "",
    `Gerencie sua assinatura em: ${manageUrl}`,
  ]
    .filter(Boolean)
    .join("\n");

  const body: Record<string, unknown> = {
    from,
    to: [to],
    subject,
    html,
    text,
  };

  if (replyTo) {
    body.reply_to = replyTo;
  }

  const response = await fetch(RESEND_API_BASE, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const payload = await response.text().catch(() => "");
    throw new Error(payload || `Resend request failed with status ${response.status}.`);
  }

  return await response.json().catch(() => ({ ok: true }));
}

function formatCurrencyBrl(amountInCents: number) {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
  }).format(amountInCents / 100);
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}
