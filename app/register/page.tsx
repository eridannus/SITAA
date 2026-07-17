import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = { title: "Registro" };

const choices = [
  {
    href: "/register/student",
    eyebrow: "Registro de alumno",
    title: "Soy alumno",
    description: "Usa tu número de cuenta UNAM y elige tu programa académico.",
  },
  {
    href: "/register/professor",
    eyebrow: "Registro de profesor",
    title: "Soy profesor",
    description: "Usa tu número de trabajador UNAM y elige tu programa principal.",
  },
];

export default function RegisterPage() {
  return (
    <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="max-w-2xl">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
          Crear cuenta
        </p>
        <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
          Elige tu tipo de registro
        </h1>
        <p className="mt-4 leading-7 text-slate-600">
          La identidad básica no concede permisos de tutoría, asesoría, tutoría par ni administración.
        </p>
      </div>

      <div className="mt-10 grid gap-6 md:grid-cols-2">
        {choices.map((choice) => (
          <Link
            key={choice.href}
            href={choice.href}
            className="group flex min-h-64 cursor-pointer flex-col rounded-3xl border border-slate-200 bg-white p-8 shadow-sm transition hover:border-emerald-400 hover:shadow-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2"
          >
            <p className="text-sm font-bold uppercase tracking-[0.16em] text-emerald-700">
              {choice.eyebrow}
            </p>
            <h2 className="mt-4 text-2xl font-bold text-slate-900">{choice.title}</h2>
            <p className="mt-4 flex-1 leading-7 text-slate-600">{choice.description}</p>
            <span className="mt-7 text-sm font-bold text-emerald-800 group-hover:text-emerald-950">
              Continuar →
            </span>
          </Link>
        ))}
      </div>
    </main>
  );
}
