export function resolveAppReturnUrl(
  request: Request,
  candidate: unknown,
  fallbackUrl: string | null | undefined,
  fallbackPath = "/workspace/settings/billing",
): string {
  const origin = request.headers.get("origin");

  if (typeof candidate === "string" && candidate.trim().length > 0) {
    return normalizeAgainstOrigin(candidate, origin, fallbackUrl);
  }

  if (origin) {
    return new URL(fallbackPath, origin).toString();
  }

  if (fallbackUrl) {
    return fallbackUrl;
  }

  throw new Error("Missing return URL for billing flow.");
}

function normalizeAgainstOrigin(
  candidate: string,
  origin: string | null,
  fallbackUrl: string | null | undefined,
) {
  if (candidate.startsWith("/")) {
    if (origin) {
      return new URL(candidate, origin).toString();
    }

    if (fallbackUrl) {
      return new URL(candidate, fallbackUrl).toString();
    }
  }

  let url: URL;
  try {
    url = new URL(candidate);
  } catch {
    throw new Error("Invalid billing return URL.");
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("Invalid billing return URL protocol.");
  }

  if (origin && url.origin !== origin) {
    throw new Error("Billing return URL origin mismatch.");
  }

  return url.toString();
}
