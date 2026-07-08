import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { getMexicoCityToday } from "@/lib/activities/date-time";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityFormOptions } from "@/types/activities";
import type { Profile } from "@/types/sitaa";
import { ActivityForm } from "./activity-form";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Nueva actividad",
};

export default async function NewActivityPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?error=sesion-requerida");
  }

  const { data: profileData, error: profileError } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8">
        <h1 className="text-3xl font-bold text-slate-900">No fue posible preparar la actividad</h1>
        <p className="mt-4 text-slate-600">Intenta nuevamente más tarde.</p>
      </section>
    );
  }

  const profile = profileData as Profile | null;

  if (!profile) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8">
        <div className="rounded-3xl border border-amber-200 bg-white p-8 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            Activación pendiente
          </p>
          <h1 className="mt-3 text-3xl font-bold text-slate-900">
            Necesitas un perfil activo en SITAA
          </h1>
          <p className="mt-4 leading-7 text-slate-600">
            Tu cuenta existe, pero aún no tiene un perfil institucional habilitado para crear actividades.
          </p>
        </div>
      </section>
    );
  }

  let options: ActivityFormOptions;

  try {
    options = await getActivityFormOptions();
  } catch {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8">
        <h1 className="text-3xl font-bold text-slate-900">No fue posible cargar el formulario</h1>
        <p className="mt-4 text-slate-600">Los catálogos operativos no están disponibles.</p>
      </section>
    );
  }

  if (options.academicPeriods.length !== 1) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="rounded-3xl border border-amber-200 bg-white p-8 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            Periodo académico requerido
          </p>
          <h1 className="mt-3 text-3xl font-bold text-slate-900">
            No es posible crear actividades en este momento
          </h1>
          <p className="mt-4 leading-7 text-slate-600">
            Debe existir exactamente un periodo académico activo. Contacta a la persona administradora de SITAA.
          </p>
          <Link href="/activities" className="mt-7 inline-flex rounded-full border border-slate-300 px-6 py-3 text-sm font-bold text-slate-700">
            Volver a actividades
          </Link>
        </div>
      </section>
    );
  }

  return (
    <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
            Operación académica
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
            Nueva actividad
          </h1>
          <p className="mt-4 max-w-2xl leading-7 text-slate-600">
            Registra la información base. Participantes, asistencia y formularios se incorporarán después.
          </p>
        </div>
        <Link href="/activities" className="rounded-full border border-slate-300 px-6 py-3 text-center text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800">
          Volver a actividades
        </Link>
      </div>

      <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
        <ActivityForm
          options={options}
          activePeriod={options.academicPeriods[0]}
          initialValues={{
            title: "",
            description: "",
            program_id: profile.primary_program_id ?? "",
            activity_type_code: "",
            service_type_code: "",
            attention_category_code: "",
            modality_code: "",
            location_type_code: "",
            location_detail: "",
            start_date: "",
            start_time: "",
            duration_mode: "one_hour",
            end_date: "",
            end_time: "",
          }}
          today={getMexicoCityToday()}
        />
      </div>
    </main>
  );
}