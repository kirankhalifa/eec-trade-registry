import { NextResponse } from "next/server";

import {
  getStaffAccessPendingUrl,
  getStaffOAuthFailureUrl,
  getStaffOAuthSuccessUrl,
} from "@/lib/staff-oauth";
import { registerStaffAccessRequest } from "@/lib/staff-access";
import { createServerSupabaseClient } from "@/lib/supabase-server";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const providerError = requestUrl.searchParams.get("error");

  if (providerError) {
    const reason = providerError === "access_denied" ? "cancelled" : "provider_error";
    console.error(`[staff-auth:provider] ${providerError}`);
    return NextResponse.redirect(getStaffOAuthFailureUrl(reason));
  }
  if (!code) {
    return NextResponse.redirect(getStaffOAuthFailureUrl("missing_code"));
  }

  const client = await createServerSupabaseClient();
  const { error } = await client.auth.exchangeCodeForSession(code);
  if (error) {
    console.error(`[staff-auth:callback] ${error.code ?? "exchange_failed"}`);
    return NextResponse.redirect(getStaffOAuthFailureUrl("exchange_failed"));
  }

  const registration = await registerStaffAccessRequest(client);
  if (!registration.ok) {
    await client.auth.signOut();
    return NextResponse.redirect(getStaffOAuthFailureUrl("request_failed"));
  }
  if (registration.data.state === "authorized") {
    return NextResponse.redirect(getStaffOAuthSuccessUrl());
  }
  return NextResponse.redirect(getStaffAccessPendingUrl(registration.data.state));
}
