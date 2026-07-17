import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = { title: "Confirmación de cuenta" };

export default function ConfirmationErrorPage() {
  return (
    <main className="mx-auto grid min-h-[70vh] max-w-4xl place-items-center px-5 py-16 sm:px-8">
      <div className="w-full rounded-3xl border border-amber-200 bg-white p-8 text-center sm:p-12">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">Confirmación</p>
        <h1 className="mt-4 text-3xl font-bold text-slate-900">El enlace no es válido o ya expiró</h1>
        <p className="mx-auto mt-5 max-w-2xl leading-7 text-slate-600">
          No fue posible confirmar la cuenta. Solicita un nuevo enlace desde Supabase Auth o intenta iniciar sesión si ya confirmaste el correo.
        </p>
        <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
          <Link href="/login" className="inline-flex min-h-12 cursor-pointer items-center justify-center rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white hover:bg-emerald-900">
            Iniciar sesión
          </Link>
          <Link href="/register" className="inline-flex min-h-12 cursor-pointer items-center justify-center rounded-full border border-slate-300 px-7 py-3 text-sm font-bold text-slate-700 hover:border-emerald-700 hover:text-emerald-800">
            Volver al registro
          </Link>
        </div>
      </div>
    </main>
  );
}
