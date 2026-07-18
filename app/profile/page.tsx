import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { AcademicProgram, Profile } from "@/types/sitaa";
import { updateProfile } from "./actions";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Mi perfil" };

const errorMessages: Record<string, string> = {
  "nombres-invalidos": "Escribe tu nombre o nombres (máximo 150 caracteres).",
  "apellido-paterno-invalido": "Escribe tu apellido paterno (máximo 150 caracteres).",
  "apellido-materno-invalido": "El apellido materno no puede exceder 150 caracteres.",
  "nombre-combinado-invalido": "El nombre visible formado por nombres y apellidos no puede exceder 200 caracteres.",
  actualizacion: "No fue posible actualizar el perfil. Intenta nuevamente.",
  "perfil-inexistente": "Tu cuenta todavía no tiene un perfil SITAA.",
};

const personTypeLabels = { student: "Alumno", professor: "Profesor" } as const;
const identifierLabels = {
  student_account: "Número de cuenta",
  worker_number: "Número de trabajador",
} as const;

type Props = { searchParams: Promise<{ error?: string | string[]; success?: string | string[] }> };
function param(value: string | string[] | undefined) { return Array.isArray(value) ? value[0] : value; }

export default async function ProfilePage({ searchParams }: Props) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user?.email) redirect("/login?error=sesion-requerida");

  const { data, error } = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (error) return <LoadError />;
  const profile = data as Profile | null;
  if (!profile) redirect("/account-status?state=missing");

  let primaryProgram: AcademicProgram | null = null;
  if (profile.primary_program_id) {
    const { data: program } = await supabase
      .from("academic_programs")
      .select("*")
      .eq("id", profile.primary_program_id)
      .maybeSingle();
    primaryProgram = (program as AcademicProgram | null) ?? null;
  }

  const params = await searchParams;
  const errorCode = param(params.error);
  const success = param(params.success) === "actualizado";

  return (
    <main className="mx-auto max-w-4xl px-4 py-10 sm:px-8 sm:py-14">
      <div className="max-w-2xl">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--sitaa-gold-dark)]">Identidad institucional</p>
        <h1 className="mt-3 text-3xl font-bold text-[var(--sitaa-blue-dark)] sm:text-4xl">Mi perfil</h1>
        <p className="mt-4 leading-7 text-slate-600">
          Puedes actualizar tus nombres y apellidos. La clasificación, identificador, programa, correo, estado y roles requieren flujos controlados.
        </p>
      </div>

      <div className="sitaa-card mt-9 p-7 sm:p-10">
        {success && <div role="status" className="sitaa-alert sitaa-alert--success mb-6">Tu perfil se actualizó correctamente.</div>}
        {errorCode && errorMessages[errorCode] && <div role="alert" className="sitaa-alert sitaa-alert--error mb-6">{errorMessages[errorCode]}</div>}

        <dl className="sitaa-detail-card grid min-w-0 gap-5 p-5 text-sm sm:grid-cols-2">
          <div className="min-w-0 sm:col-span-2"><dt className="font-semibold text-slate-500">Correo</dt><dd className="sitaa-wrap-anywhere mt-1 text-slate-900">{user.email}</dd></div>
          <div><dt className="font-semibold text-slate-500">Tipo de cuenta</dt><dd className="mt-1 text-slate-900">{profile.account_kind === "technical" ? "Técnica interna" : "Institucional"}</dd></div>
          {profile.person_type && <div><dt className="font-semibold text-slate-500">Tipo de persona</dt><dd className="mt-1 text-slate-900">{personTypeLabels[profile.person_type]}</dd></div>}
          {profile.institutional_id_type && profile.institutional_id_value && <div><dt className="font-semibold text-slate-500">{identifierLabels[profile.institutional_id_type]}</dt><dd className="mt-1 break-words text-slate-900">{profile.institutional_id_value}</dd></div>}
          {profile.account_kind !== "technical" && <div><dt className="font-semibold text-slate-500">Programa principal</dt><dd className="mt-1 break-words text-slate-900">{primaryProgram?.name ?? "Programa no disponible"}</dd></div>}
        </dl>

        <form action={updateProfile} className="mt-7 grid gap-5 sm:grid-cols-2">
          <div className="sm:col-span-2"><label htmlFor="first_names" className="sitaa-form-label">Nombre(s)</label><input id="first_names" name="first_names" autoComplete="given-name" defaultValue={profile.first_names ?? ""} required maxLength={150} className="sitaa-field mt-2" /></div>
          <div><label htmlFor="paternal_surname" className="sitaa-form-label">Apellido paterno {profile.account_kind === "technical" && <span className="font-normal text-[var(--sitaa-text-secondary)]">(opcional)</span>}</label><input id="paternal_surname" name="paternal_surname" autoComplete="family-name" defaultValue={profile.paternal_surname ?? ""} required={profile.account_kind !== "technical"} maxLength={150} className="sitaa-field mt-2" /></div>
          <div><label htmlFor="maternal_surname" className="sitaa-form-label">Apellido materno <span className="font-normal text-[var(--sitaa-text-secondary)]">(opcional)</span></label><input id="maternal_surname" name="maternal_surname" autoComplete="additional-name" defaultValue={profile.maternal_surname ?? ""} maxLength={150} className="sitaa-field mt-2" /></div>
          <p className="sitaa-help-text sm:col-span-2">SITAA construirá el nombre visible a partir de estos campos.</p>
          <div className="flex flex-col gap-3 sm:col-span-2 sm:flex-row">
            <button type="submit" className="sitaa-primary-action">Guardar nombres</button>
            <Link href="/dashboard" className="sitaa-secondary-action">Volver al panel</Link>
          </div>
        </form>
      </div>
    </main>
  );
}

function LoadError() {
  return <section className="mx-auto max-w-4xl px-5 py-16"><div className="sitaa-alert sitaa-alert--error p-8"><h1 className="text-3xl font-bold">No fue posible cargar tu perfil</h1><p className="mt-4">Intenta nuevamente más tarde.</p></div></section>;
}
