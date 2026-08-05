import { NextResponse } from "next/server";

import {
  getStaffOAuthFailureUrl,
  getStaffOAuthSuccessUrl,
} from "@/lib/staff-oauth";
import { createServerSupabaseClient } from "@/lib/supabase-server";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const providerError = requestUrl.searchParams.get("error");

  if (providerError || !code) {
    return NextResponse.redirect(getStaffOAuthFailureUrl("cancelled"));
  }

  const client = await createServerSupabaseClient();
  const { error } = await client.auth.exchangeCodeForSession(code);
  if (error) {
    console.error(`[staff-auth:callback] ${error.code ?? "exchange_failed"}`);
    return NextResponse.redirect(getStaffOAuthFailureUrl("exchange_failed"));
  }

  return NextResponse.redirect(getStaffOAuthSuccessUrl());
}
