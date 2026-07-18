import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Estado del sistema",
};

export default function HealthPage() {
  return (
    <section className="mx-auto grid min-h-[65vh] max-w-6xl place-items-center px-5 py-16 sm:px-8">
      <div className="sitaa-card w-full max-w-lg p-8 text-center sm:p-12">
        <span className="mx-auto grid size-16 place-items-center rounded-full border border-[var(--sitaa-success-border)] bg-[var(--sitaa-success-background)] text-2xl text-[var(--sitaa-success-foreground)]" aria-hidden="true">
          ✓
        </span>
        <p className="sitaa-section-eyebrow mt-6">Estado del servicio</p>
        <h1 className="mt-3 text-4xl font-bold tracking-tight text-[var(--sitaa-blue-dark)]">SITAA OK</h1>
        <p className="mt-4 text-slate-600">La aplicación está funcionando correctamente.</p>
      </div>
    </section>
  );
}
