import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { AcademicProgram, Profile } from "@/types/sitaa";
import { updateProfile } from "./actions";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Mi perfil" };

const errorMessages: Record<string, string> = {
  "nombre-invalido": "Escribe un nombre completo válido (máximo 200 caracteres).",
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
    <main className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="max-w-2xl">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Identidad institucional</p>
        <h1 className="mt-3 text-3xl font-bold text-emerald-950 sm:text-4xl">Mi perfil</h1>
        <p className="mt-4 leading-7 text-slate-600">
          Puedes actualizar tu nombre completo. La clasificación, identificador, programa, correo, estado y roles requieren flujos controlados.
        </p>
      </div>

      <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
        {success && <div role="status" className="mb-6 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">Tu perfil se actualizó correctamente.</div>}
        {errorCode && errorMessages[errorCode] && <div role="alert" className="mb-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{errorMessages[errorCode]}</div>}

        <dl className="grid min-w-0 gap-5 rounded-2xl bg-slate-50 p-5 text-sm sm:grid-cols-2">
          <div className="min-w-0 sm:col-span-2"><dt className="font-semibold text-slate-500">Correo</dt><dd className="mt-1 break-all text-slate-900">{user.email}</dd></div>
          <div><dt className="font-semibold text-slate-500">Tipo de cuenta</dt><dd className="mt-1 text-slate-900">{profile.account_kind === "technical" ? "Técnica interna" : "Institucional"}</dd></div>
          {profile.person_type && <div><dt className="font-semibold text-slate-500">Tipo de persona</dt><dd className="mt-1 text-slate-900">{personTypeLabels[profile.person_type]}</dd></div>}
          {profile.institutional_id_type && profile.institutional_id_value && <div><dt className="font-semibold text-slate-500">{identifierLabels[profile.institutional_id_type]}</dt><dd className="mt-1 break-words text-slate-900">{profile.institutional_id_value}</dd></div>}
          {profile.account_kind !== "technical" && <div><dt className="font-semibold text-slate-500">Programa principal</dt><dd className="mt-1 break-words text-slate-900">{primaryProgram?.name ?? "Programa no disponible"}</dd></div>}
        </dl>

        <form action={updateProfile} className="mt-7">
          <label htmlFor="full_name" className="block text-sm font-semibold text-slate-700">Nombre completo</label>
          <input id="full_name" name="full_name" autoComplete="name" defaultValue={profile.full_name ?? ""} required minLength={2} maxLength={200} className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
          <div className="mt-6 flex flex-col gap-3 sm:flex-row">
            <button type="submit" className="cursor-pointer rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Guardar nombre</button>
            <Link href="/dashboard" className="cursor-pointer rounded-full border border-slate-300 px-6 py-3 text-center text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800">Volver al panel</Link>
          </div>
        </form>
      </div>
    </main>
  );
}

function LoadError() {
  return <section className="mx-auto max-w-4xl px-5 py-16"><div className="rounded-3xl border border-red-200 bg-white p-8"><h1 className="text-3xl font-bold text-slate-900">No fue posible cargar tu perfil</h1><p className="mt-4 text-slate-600">Intenta nuevamente más tarde.</p></div></section>;
}
