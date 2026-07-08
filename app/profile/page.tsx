import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { AcademicProgram, Profile } from "@/types/sitaa";
import { updateProfile } from "./actions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Mi perfil",
};

const errorMessages: Record<string, string> = {
  "datos-invalidos": "Revisa los datos capturados e inténtalo nuevamente.",
  "programa-invalido": "El programa seleccionado no está disponible.",
  "programa-requerido": "Selecciona un programa académico para guardar el perfil.",
  actualizacion: "No fue posible actualizar el perfil. Intenta nuevamente.",
  "perfil-inexistente": "Tu cuenta todavía no tiene un perfil institucional activado.",
};

type ProfilePageProps = {
  searchParams: Promise<{
    error?: string | string[];
    success?: string | string[];
  }>;
};

function getParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function ProfilePage({ searchParams }: ProfilePageProps) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect("/login?error=sesion-requerida");
  }

  const [{ data: profileData, error: profileError }, { data: programData, error: programError }] =
    await Promise.all([
      supabase.from("profiles").select("*").eq("id", user.id).maybeSingle(),
      supabase.from("academic_programs").select("*").order("name", { ascending: true }),
    ]);

  if (profileError) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="rounded-3xl border border-red-200 bg-white p-8 sm:p-12">
          <h1 className="text-3xl font-bold text-slate-900">No fue posible cargar tu perfil</h1>
          <p className="mt-4 leading-7 text-slate-600">
            Intenta nuevamente. Si el problema continúa, contacta a la persona administradora de SITAA.
          </p>
        </div>
      </section>
    );
  }

  const profile = profileData as Profile | null;

  if (!profile) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="rounded-3xl border border-amber-200 bg-white p-8 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            Activación pendiente
          </p>
          <h1 className="mt-3 text-3xl font-bold text-slate-900">Tu perfil aún no está disponible</h1>
          <p className="mt-4 leading-7 text-slate-600">
            Tu cuenta existe, pero la institución todavía no ha creado tu perfil en SITAA.
          </p>
        </div>
      </section>
    );
  }

  const programs = programError
    ? []
    : ((programData ?? []) as AcademicProgram[])
        .filter((program) => program.is_active !== false)
        .sort((left, right) => left.name.localeCompare(right.name, "es"));
  const programsUnavailable = Boolean(programError);
  const programsEmpty = !programsUnavailable && programs.length === 0;
  const params = await searchParams;
  const errorCode = getParam(params.error);
  const successCode = getParam(params.success);
  const errorMessage = errorCode ? errorMessages[errorCode] : undefined;

  return (
    <main className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="max-w-2xl">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
          Identidad institucional
        </p>
        <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
          Mi perfil
        </h1>
        <p className="mt-4 leading-7 text-slate-600">
          Actualiza tus datos básicos. Los roles y el estado de activación son administrados por la institución.
        </p>
      </div>

      <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
        {successCode === "actualizado" && (
          <div role="status" className="mb-6 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
            Tu perfil se actualizó correctamente.
          </div>
        )}
        {errorMessage && (
          <div role="alert" className="mb-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
            {errorMessage}
          </div>
        )}
        {programsUnavailable && (
          <div role="status" className="mb-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-800">
            No fue posible cargar los programas académicos. La actualización estará disponible cuando el catálogo pueda consultarse.
          </div>
        )}
        {programsEmpty && (
          <div role="status" className="mb-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-800">
            No hay programas académicos disponibles. Contacta a la persona administradora de SITAA.
          </div>
        )}

        <form action={updateProfile} className="grid min-w-0 gap-6 sm:grid-cols-2">
          <div className="min-w-0 sm:col-span-2">
            <label htmlFor="email" className="block text-sm font-semibold text-slate-700">Correo</label>
            <p id="email" className="mt-2 min-w-0 break-all rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-slate-600">{user.email}</p>
          </div>
          <div className="min-w-0 sm:col-span-2">
            <label htmlFor="first_names" className="block text-sm font-semibold text-slate-700">Nombre(s)</label>
            <input id="first_names" name="first_names" defaultValue={profile.first_names} required maxLength={100} className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
          </div>
          <div>
            <label htmlFor="paternal_surname" className="block text-sm font-semibold text-slate-700">Apellido paterno</label>
            <input id="paternal_surname" name="paternal_surname" defaultValue={profile.paternal_surname} required maxLength={100} className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
          </div>
          <div>
            <label htmlFor="maternal_surname" className="block text-sm font-semibold text-slate-700">Apellido materno</label>
            <input id="maternal_surname" name="maternal_surname" defaultValue={profile.maternal_surname ?? ""} maxLength={100} className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
          </div>
          <div>
            <label htmlFor="person_type" className="block text-sm font-semibold text-slate-700">Tipo de persona</label>
            <select id="person_type" name="person_type" defaultValue={profile.person_type} className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100">
              <option value="student">Alumno</option>
              <option value="worker">Trabajador</option>
            </select>
          </div>
          <div>
            <label htmlFor="institutional_id_value" className="block text-sm font-semibold text-slate-700">Identificador institucional</label>
            <input id="institutional_id_value" name="institutional_id_value" defaultValue={profile.institutional_id_value} required maxLength={50} className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
            <p className="mt-2 text-xs leading-5 text-slate-500">Número de cuenta para alumnos o número de trabajador para personal.</p>
          </div>
          <div className="min-w-0 sm:col-span-2">
            <label htmlFor="primary_program_id" className="block text-sm font-semibold text-slate-700">Programa académico principal</label>
            {programsUnavailable || programsEmpty ? (
              <select id="primary_program_id" disabled className="mt-2 w-full min-w-0 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-slate-500">
                <option>Programas no disponibles</option>
              </select>
            ) : (
              <select id="primary_program_id" name="primary_program_id" defaultValue={profile.primary_program_id ?? ""} required aria-describedby="primary_program_help" className="mt-2 w-full min-w-0 rounded-xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100">
                <option value="" disabled>Selecciona un programa</option>
                {programs.map((program) => (
                  <option key={program.id} value={program.id}>{program.name}</option>
                ))}
              </select>
            )}
            <p id="primary_program_help" className="mt-2 text-xs leading-5 text-slate-500">
              El programa académico es obligatorio para completar tu perfil.
            </p>
          </div>
          <div className="sm:col-span-2 flex flex-col gap-3 pt-2 sm:flex-row sm:items-center">
            <button type="submit" disabled={programsUnavailable || programsEmpty} className="rounded-full bg-emerald-800 disabled:cursor-not-allowed disabled:bg-slate-400 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus:outline-none focus:ring-4 focus:ring-emerald-200 cursor-pointer disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
              Guardar cambios
            </button>
            <a href="/dashboard" className="rounded-full border border-slate-300 px-6 py-3 text-center text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
              Volver al panel
            </a>
          </div>
        </form>
      </div>
    </main>
  );
}