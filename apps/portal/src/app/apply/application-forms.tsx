"use client";

import { useActionState, useState } from "react";

import {
  checkApplicationAction,
  submitApplicationAction,
  type ApplicationState,
} from "@/app/apply/actions";
import { ReferenceBlock } from "@/components/reference-block";
import type { ApplicationOptions } from "@/lib/license-application";
import { REGISTRY_CONFIG } from "@/lib/registry-config";

const initial: ApplicationState = {};

export function ApplicationForms({ options }: { options: ApplicationOptions }) {
  const [mode, setMode] = useState<"new" | "renewal">("new");
  const [state, submit, pending] = useActionState(submitApplicationAction, initial);
  const [lookup, check, checking] = useActionState(checkApplicationAction, initial);
  const jurisdiction = options.jurisdictions.find(
    (item) => item.code === REGISTRY_CONFIG.jurisdiction.code,
  );
  const groups = options.endorsements.reduce<
    Array<{ label: string; options: ApplicationOptions["endorsements"] }>
  >((result, endorsement) => {
    const existing = result.find((group) => group.label === endorsement.group);
    if (existing) existing.options.push(endorsement);
    else result.push({ label: endorsement.group, options: [endorsement] });
    return result;
  }, []);

  return (
    <div className="application-workspace">
      {state.reference && state.token ? (
        <section className="application-receipt" aria-live="polite">
          <p className="eyebrow">Application received</p>
          <h2>Save both values now.</h2>
          <p>
            The private token is shown once and cannot be recovered. You need the
            application reference and token together to check the decision later.
          </p>
          <ReferenceBlock
            label="Application reference"
            reference={state.reference}
            status="Submitted"
          />
          <ReferenceBlock label="Private status token · shown once" reference={state.token} />
        </section>
      ) : (
        <section className="application-intake">
          <div className="application-mode" aria-label="Application type">
            <button
              aria-pressed={mode === "new"}
              onClick={() => setMode("new")}
              type="button"
            >
              New license
            </button>
            <button
              aria-pressed={mode === "renewal"}
              onClick={() => setMode("renewal")}
              type="button"
            >
              Renew a license
            </button>
          </div>

          {mode === "renewal" ? (
            <form action={submit} className="verification-form application-form application-renewal-form">
              <input name="application_type" type="hidden" value="renewal" />
              <input aria-hidden="true" autoComplete="off" className="form-honeypot" name="website" tabIndex={-1} />
              <div className="application-form-heading">
                <p className="eyebrow">Renew existing authority</p>
                <h2>Enter the current license reference.</h2>
                <p>
                  The registry copies the holder, license type, region, and active
                  endorsements from the issued record. You do not need to re-enter them.
                </p>
              </div>
              <label className="field">
                <span>Current LIC reference</span>
                <input
                  autoComplete="off"
                  maxLength={128}
                  name="existing_license_reference"
                  placeholder="EEC-LIC-…"
                  required
                  spellCheck={false}
                />
              </label>
              {state.error && <p className="staff-flash staff-flash-error" role="alert">{state.error}</p>}
              <button className="button button-primary" disabled={pending}>
                {pending ? "Submitting…" : "Request renewal"}
              </button>
            </form>
          ) : (
            <form action={submit} className="verification-form application-form">
              <input name="application_type" type="hidden" value="new" />
              <input aria-hidden="true" autoComplete="off" className="form-honeypot" name="website" tabIndex={-1} />
              <div className="application-form-heading">
                <p className="eyebrow">New authority</p>
                <h2>Tell the licensing office what the business needs.</h2>
                <p>Submitting creates a review case. It does not issue authority automatically.</p>
              </div>
              <label className="field">
                <span>Applicant or business name</span>
                <input maxLength={200} name="applicant_name" required />
              </label>
              <label className="field">
                <span>Discord name or contact label</span>
                <input maxLength={300} name="contact_label" required />
                <small>No email is required.</small>
              </label>
              <label className="field">
                <span>License type</span>
                <select defaultValue="" name="license_class_code" required>
                  <option disabled value="">Choose a license type</option>
                  {options.license_classes.map((item) => (
                    <option key={item.code} value={item.code}>{item.label}</option>
                  ))}
                </select>
              </label>
              {jurisdiction ? (
                <div className="derived-choice">
                  <span>Region</span>
                  <strong>{jurisdiction.label}</strong>
                  <small>Assigned automatically for this registry</small>
                  <input name="jurisdiction_code" type="hidden" value={jurisdiction.code} />
                </div>
              ) : (
                <p className="staff-flash staff-flash-error" role="alert">
                  The configured application region is unavailable. New applications are paused.
                </p>
              )}
              <div className="endorsement-groups">
                <p className="field-label">Requested endorsements</p>
                {groups.map((group) => (
                  <fieldset className="endorsement-group" key={group.label}>
                    <legend>{group.label}</legend>
                    {group.options.map((item) => (
                      <label className="staff-checkbox" key={item.code}>
                        <input name="endorsement_codes" type="checkbox" value={item.code} />
                        <span><strong>{item.label}</strong><small>{item.description}</small></span>
                      </label>
                    ))}
                  </fieldset>
                ))}
              </div>
              <label className="field">
                <span>What will the license be used for?</span>
                <textarea minLength={10} maxLength={4000} name="statement" required rows={5} />
              </label>
              {state.error && <p className="staff-flash staff-flash-error" role="alert">{state.error}</p>}
              <button className="button button-primary" disabled={pending || !jurisdiction}>
                {pending ? "Submitting…" : "Submit application"}
              </button>
            </form>
          )}
        </section>
      )}

      <section className="application-status-check">
        <div>
          <p className="eyebrow">Already applied?</p>
          <h2>Check the review status.</h2>
          <p>Use the application reference and one-time private token from your receipt.</p>
        </div>
        <form action={check} className="verification-form">
          <label className="field">
            <span>Application reference</span>
            <input name="reference" required />
          </label>
          <label className="field">
            <span>Private status token</span>
            <input name="token" required />
          </label>
          {lookup.error && <p className="staff-flash staff-flash-error" role="alert">{lookup.error}</p>}
          {lookup.status && lookup.reference && (
            <ReferenceBlock
              label="Application reference"
              reference={lookup.reference}
              status={lookup.status.replaceAll("_", " ")}
            />
          )}
          <button className="button button-secondary" disabled={checking}>
            {checking ? "Checking…" : "Check status"}
          </button>
        </form>
      </section>
    </div>
  );
}
