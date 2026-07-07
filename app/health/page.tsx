import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Estado del sistema",
};

export default function HealthPage() {
  return (
    <section className="mx-auto grid min-h-[65vh] max-w-6xl place-items-center px-5 py-16 sm:px-8">
      <div className="w-full max-w-lg rounded-3xl border border-emerald-900/10 bg-white p-8 text-center shadow-xl shadow-emerald-950/5 sm:p-12">
        <span className="mx-auto grid size-16 place-items-center rounded-full bg-emerald-100 text-2xl text-emerald-800" aria-hidden="true">
          ✓
        </span>
        <p className="mt-6 text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Estado del servicio</p>
        <h1 className="mt-3 text-4xl font-bold tracking-tight text-emerald-950">SITAA OK</h1>
        <p className="mt-4 text-slate-600">La aplicación está funcionando correctamente.</p>
      </div>
    </section>
  );
}