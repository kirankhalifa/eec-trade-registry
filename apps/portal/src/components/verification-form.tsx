interface VerificationFormProps {
  kind: "dealer" | "license";
  reference: string | null;
}

export function VerificationForm({ kind, reference }: VerificationFormProps) {
  const noun = kind === "dealer" ? "dealer" : "license";

  return (
    <form className="verification-form" action={`/verify/${kind}`} method="get">
      <label className="field" htmlFor={`${kind}-reference`}>
        <span>Public {noun} reference</span>
        <input
          id={`${kind}-reference`}
          name="reference"
          defaultValue={reference ?? ""}
          maxLength={128}
          autoComplete="off"
          spellCheck={false}
          required
          placeholder={kind === "dealer" ? "DLR-DEMO-A7K9" : "LIC-DEMO-4Q2M"}
        />
      </label>
      <button className="button" type="submit">
        Verify {noun}
      </button>
      <p>
        Enter the exact public reference. Name and organization search are not
        enabled.
      </p>
    </form>
  );
}
