import type { Metadata } from "next";
import Link from "next/link";
import { GoogleRegistrationStart } from "@/components/google-registration-start";
import { guardPublicRegistrationEntry } from "@/lib/auth/guard-public-registration";

export const metadata: Metadata = { title: "Registro de alumno" };
export const dynamic = "force-dynamic";

type Props = { searchParams: Promise<{ error?: string | string[] }> };

export default async function StudentRegistrationPage({ searchParams }: Props) {
  await guardPublicRegistrationEntry("/complete-registration/student");
  const params = await searchParams;
  const hasError = Boolean(Array.isArray(params.error) ? params.error[0] : params.error);
  return (
    <main className="mx-auto max-w-4xl px-4 py-10 sm:px-8 sm:py-14">
      <Link href="/register" className="inline-flex min-h-11 cursor-pointer items-center rounded-lg px-2 text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]">
        ← Cambiar tipo de registro
      </Link>
      <div className="sitaa-surface mt-4 rounded-3xl p-6 sm:p-9">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--sitaa-gold-dark)]">Alumno</p>
        <h1 className="mt-3 text-3xl font-bold text-[var(--sitaa-blue-dark)]">Comenzar registro de alumno</h1>
        <p className="mt-4 leading-7 text-slate-600">
          Google autenticará tu cuenta. Después capturarás tu nombre, número de cuenta UNAM y programa académico dentro de SITAA.
        </p>
        {hasError && <p role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">No fue posible iniciar el acceso con Google. Intenta nuevamente.</p>}
        <div className="mt-6 rounded-2xl bg-[var(--sitaa-blue-light)] p-4 text-sm leading-6 text-[var(--sitaa-blue-dark)]">
          Puedes usar cualquier cuenta de Google. Recomendamos una cuenta personal controlada por ti; una cuenta compartida o de oficina reduce la trazabilidad individual.
        </div>
        <GoogleRegistrationStart personType="student" />
      </div>
    </main>
  );
}
