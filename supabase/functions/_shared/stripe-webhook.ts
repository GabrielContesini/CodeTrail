function parseStripeSignature(signatureHeader: string | null): {
  timestamp: string | null;
  signatures: string[];
} {
  if (!signatureHeader) {
    return { timestamp: null, signatures: [] };
  }

  const parts = signatureHeader.split(",").map((part) => part.trim());
  const signatures: string[] = [];
  let timestamp: string | null = null;

  for (const part of parts) {
    const [key, value] = part.split("=", 2);
    if (key === "t") {
      timestamp = value ?? null;
    }
    if (key === "v1" && value) {
      signatures.push(value);
    }
  }

  return { timestamp, signatures };
}

async function hexHmacSha256(secret: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(signature))
    .map((item) => item.toString(16).padStart(2, "0"))
    .join("");
}

export async function validateStripeWebhook(
  request: Request,
  rawBody: string,
): Promise<boolean> {
  const endpointSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!endpointSecret) {
    const secretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
    return secretKey.startsWith("sk_test_");
  }

  const signatureHeader = request.headers.get("stripe-signature");
  const { timestamp, signatures } = parseStripeSignature(signatureHeader);

  if (!timestamp || signatures.length == 0) {
    return false;
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const parsedTimestamp = Number(timestamp);
  if (!Number.isFinite(parsedTimestamp) || Math.abs(nowSeconds - parsedTimestamp) > 300) {
    return false;
  }

  const signedPayload = `${timestamp}.${rawBody}`;
  const expected = await hexHmacSha256(endpointSecret, signedPayload);

  return signatures.some((candidate) => candidate.toLowerCase() === expected.toLowerCase());
}
