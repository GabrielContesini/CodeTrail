import type { User } from "https://esm.sh/@supabase/supabase-js@2.49.8";

import { createServiceRoleClient, createUserClient } from "./supabase.ts";

export interface AuthenticatedContext {
  authHeader: string;
  serviceClient: ReturnType<typeof createServiceRoleClient>;
  userClient: ReturnType<typeof createUserClient>;
  user: User;
}

export async function requireAuthenticatedContext(
  request: Request,
): Promise<AuthenticatedContext> {
  const authHeader =
    request.headers.get("x-supabase-auth") ??
    request.headers.get("Authorization");
  if (!authHeader) {
    throw new Error("Missing Authorization header.");
  }

  const userClient = createUserClient(authHeader);
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) {
    throw new Error("Unauthorized request.");
  }

  return {
    authHeader,
    serviceClient: createServiceRoleClient(),
    userClient,
    user: data.user,
  };
}
