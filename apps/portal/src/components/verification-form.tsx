interface VerificationFormProps {
  reference: string | null;
}

export function VerificationForm({ reference }: VerificationFormProps) {
  return (
    <form className="verification-form verification-form-single" action="/verify" method="get">
      <label className="field" htmlFor="verification-reference">
        <span>Dealer or license reference</span>
        <input
          id="verification-reference"
          name="reference"
          defaultValue={reference ?? ""}
          maxLength={128}
          autoComplete="off"
          spellCheck={false}
          required
          placeholder="EEC-DLR-… or EEC-LIC-…"
        />
      </label>
      <button className="button" type="submit">
        Verify record
      </button>
      <p>
        The DLR or LIC prefix identifies the record. Names and organizations
        cannot be searched.
      </p>
    </form>
  );
}
