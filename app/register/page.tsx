import type { Metadata } from "next";
import Link from "next/link";
import { guardPublicRegistrationEntry } from "@/lib/auth/guard-public-registration";

export const metadata: Metadata = { title: "Registro" };
export const dynamic = "force-dynamic";

const choices = [
  {
    href: "/register/student",
    eyebrow: "Registro de alumno",
    title: "Soy alumno",
    description: "Autentícate con Google y después completa tu número de cuenta y programa.",
  },
  {
    href: "/register/professor",
    eyebrow: "Registro de profesor",
    title: "Soy profesor",
    description: "Autentícate con Google y después completa tu número de trabajador y programa.",
  },
];

export default async function RegisterPage() {
  await guardPublicRegistrationEntry();
  return (
    <main className="mx-auto max-w-5xl px-4 py-10 sm:px-8 sm:py-14">
      <div className="max-w-2xl">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--sitaa-gold-dark)]">
          Crear cuenta
        </p>
        <h1 className="mt-3 text-3xl font-bold tracking-tight text-[var(--sitaa-blue-dark)] sm:text-4xl">
          Elige tu tipo de registro
        </h1>
        <p className="mt-4 leading-7 text-slate-600">
          Primero continúa con cualquier cuenta de Google controlada individualmente. Tus datos institucionales se solicitarán sólo después de autenticarte y no concederán permisos académicos ni administrativos.
        </p>
      </div>

      <div className="mt-8 grid gap-5 md:grid-cols-2">
        {choices.map((choice) => (
          <Link
            key={choice.href}
            href={choice.href}
            className="group flex min-h-52 cursor-pointer flex-col rounded-3xl border border-slate-200 bg-white p-7 shadow-sm transition hover:border-[var(--sitaa-blue)] hover:shadow-lg"
          >
            <p className="text-sm font-bold uppercase tracking-[0.16em] text-[var(--sitaa-gold-dark)]">
              {choice.eyebrow}
            </p>
            <h2 className="mt-4 text-2xl font-bold text-slate-900">{choice.title}</h2>
            <p className="mt-4 flex-1 leading-7 text-slate-600">{choice.description}</p>
            <span className="mt-7 text-sm font-bold text-[var(--sitaa-blue)]">
              Continuar →
            </span>
          </Link>
        ))}
      </div>
    </main>
  );
}
