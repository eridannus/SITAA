import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = { title: "Revisa tu correo" };

export default function CheckEmailPage() {
  return (
    <main className="mx-auto grid min-h-[70vh] max-w-4xl place-items-center px-5 py-16 sm:px-8">
      <div className="w-full rounded-3xl border border-emerald-200 bg-white p-8 text-center shadow-xl shadow-emerald-950/5 sm:p-12">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
          Verificación requerida
        </p>
        <h1 className="mt-4 text-3xl font-bold text-emerald-950">Revisa tu correo</h1>
        <p className="mx-auto mt-5 max-w-2xl leading-7 text-slate-600">
          Enviamos un enlace para verificar tu correo. Al confirmarlo, tu cuenta recibirá acceso básico a SITAA.
        </p>
        <p className="mx-auto mt-3 max-w-2xl text-sm leading-6 text-slate-500">
          El registro no concede automáticamente funciones de tutor par, tutor, asesor, comité o administración.
        </p>
        <Link
          href="/login"
          className="mt-8 inline-flex min-h-12 cursor-pointer items-center justify-center rounded-full border border-slate-300 px-7 py-3 text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2"
        >
          Ir a iniciar sesión
        </Link>
      </div>
    </main>
  );
}
