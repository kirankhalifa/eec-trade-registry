import Link from "next/link";

export default function NotFound() {
  return (
    <main className="detail-main">
      <section className="notice-panel">
        <p className="eyebrow">Registry notice</p>
        <h1>That catalogue entry is not publicly verifiable.</h1>
        <p>
          The reference may be invalid, unpublished, withdrawn, or outside its
          effective publication dates.
        </p>
        <Link className="button button-primary" href="/">
          Return to catalogue
        </Link>
      </section>
    </main>
  );
}
