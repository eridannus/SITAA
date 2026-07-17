import type { Metadata } from "next";
import Link from "next/link";
import { RegistrationForm } from "@/components/registration-form";
import { getPublicRegistrationPrograms } from "@/lib/registration/programs";
import type { RegistrationProgram } from "@/types/registration";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Registro de alumno" };

export default async function StudentRegistrationPage() {
  let programs: RegistrationProgram[] = [];
  try {
    programs = await getPublicRegistrationPrograms();
  } catch {
    return <RegistrationUnavailable />;
  }

  if (!programs.length) return <RegistrationUnavailable />;

  return (
    <main className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
      <Link href="/register" className="cursor-pointer text-sm font-bold text-emerald-800 hover:text-emerald-950">
        ← Cambiar tipo de registro
      </Link>
      <div className="mt-6 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Alumno</p>
        <h1 className="mt-3 text-3xl font-bold text-emerald-950">Crear cuenta de alumno</h1>
        <p className="mt-4 leading-7 text-slate-600">
          Después de verificar tu correo tendrás acceso básico. No serás tutor par automáticamente.
        </p>
        <RegistrationForm personType="student" programs={programs} />
      </div>
    </main>
  );
}

function RegistrationUnavailable() {
  return (
    <main className="mx-auto max-w-3xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="rounded-3xl border border-amber-200 bg-white p-8 sm:p-12">
        <h1 className="text-3xl font-bold text-slate-900">Registro no disponible temporalmente</h1>
        <p className="mt-4 leading-7 text-slate-600">
          No fue posible cargar los programas académicos. Intenta nuevamente más tarde.
        </p>
      </div>
    </main>
  );
}
