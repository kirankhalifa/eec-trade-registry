"use server";

import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/supabase-server";

export interface ApplicationState { error?: string; reference?: string; status?: string; token?: string }
const schema=z.object({ application_type:z.enum(["new","renewal"]),applicant_name:z.string().trim().min(2).max(200),
  contact_label:z.string().trim().min(2).max(300),existing_license_reference:z.string().trim().max(128).default(""),
  jurisdiction_code:z.string().trim().min(1).max(50),license_class_code:z.string().trim().min(1).max(50),
  statement:z.string().trim().min(10).max(4000),website:z.string().max(0).default("") });

export async function submitApplicationAction(_previous: ApplicationState,form: FormData):Promise<ApplicationState>{
  const parsed=schema.safeParse(Object.fromEntries(form.entries())); if(!parsed.success)return{error:"Check every required field and provide a useful statement."};
  const input=parsed.data; const endorsements=form.getAll("endorsement_codes").filter((value):value is string=>typeof value==="string");
  const client=await createServerSupabaseClient(); const {data,error}=await client.rpc("public_submit_license_application",{
    p_applicant_name:input.applicant_name,p_application_type:input.application_type,p_contact_label:input.contact_label,
    p_endorsement_codes:endorsements,p_existing_license_reference:input.existing_license_reference||null,
    p_jurisdiction_code:input.jurisdiction_code,p_license_class_code:input.license_class_code,p_request_id:crypto.randomUUID(),p_statement:input.statement,
  });
  if(error){console.error(`[public-application] ${error.code??"unknown"}`);return{error:error.message.includes("renewal_license_not_found")?"That existing license reference was not found.":"The registry could not accept the application. No record was created."};}
  const row=Array.isArray(data)?data[0]:null; if(!row)return{error:"The registry returned no receipt."};
  return{reference:String(row.public_reference),token:String(row.status_token)};
}

export async function checkApplicationAction(_previous:ApplicationState,form:FormData):Promise<ApplicationState>{
  const reference=String(form.get("reference")??"").trim();const token=String(form.get("token")??"").trim();
  if(!reference||!token)return{error:"Enter both the application reference and private status token."};
  const client=await createServerSupabaseClient();const{data,error}=await client.rpc("public_get_license_application_status",{p_reference:reference,p_status_token:token});
  if(error)return{error:"Status lookup is temporarily unavailable."};const row=Array.isArray(data)?data[0]:null;
  return row?{reference:String(row.public_reference),status:String(row.status)}:{error:"No application matched that reference and private token."};
}
