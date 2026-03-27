type LogLevel = "info" | "warn" | "error";

const REDACTED_KEYS = [
  "authorization",
  "cookie",
  "secret",
  "token",
  "password",
  "apikey",
  "api_key",
  "clientsecret",
  "client_secret",
];

export function createRequestId(request?: Request) {
  return request?.headers.get("x-request-id") ?? crypto.randomUUID();
}

export function logFunctionEvent(options: {
  area: string;
  event: string;
  level?: LogLevel;
  requestId?: string;
  userId?: string | null;
  status?: number;
  metadata?: Record<string, unknown>;
}) {
  const level = options.level ?? "info";
  const payload = sanitize({
    timestamp: new Date().toISOString(),
    scope: "codetrail-billing",
    area: options.area,
    event: options.event,
    requestId: options.requestId,
    userId: options.userId,
    status: options.status,
    metadata: options.metadata,
  });

  console[level](JSON.stringify(payload));
}

function sanitize(value: unknown, depth = 0): unknown {
  if (value == null || typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return value;
  }

  if (depth >= 4) {
    return "[truncated]";
  }

  if (Array.isArray(value)) {
    return value.slice(0, 20).map((entry) => sanitize(entry, depth + 1));
  }

  if (typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).slice(0, 50).map(([key, entry]) => {
        if (shouldRedact(key)) {
          return [key, "[redacted]"];
        }
        return [key, sanitize(entry, depth + 1)];
      }),
    );
  }

  return String(value);
}

function shouldRedact(key: string) {
  const normalized = key.toLowerCase().replace(/[^a-z0-9_]/g, "");
  return REDACTED_KEYS.some((candidate) => normalized.includes(candidate));
}
