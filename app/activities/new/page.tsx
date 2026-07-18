import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { getActivityScopeAccess } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { getMexicoCityToday } from "@/lib/activities/date-time";
import type { ActivityFormOptions } from "@/types/activities";
import { ActivityForm } from "./activity-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Nueva actividad" };

export default async function NewActivityPage() {
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");
  if (context.error) return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible preparar la actividad</h1><p className="mt-4">Intenta nuevamente más tarde.</p></section>;
  if (!context.profile) return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">Necesitas un perfil activo en SITAA</h1><p className="mt-4">Tu cuenta existe, pero aún no tiene un perfil institucional habilitado para crear actividades.</p></section>;

  let options: ActivityFormOptions;
  try { options = await getActivityFormOptions(); }
  catch { return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible cargar el formulario</h1><p className="mt-4">Los catálogos operativos no están disponibles.</p></section>; }


  const access = getActivityScopeAccess(context, options.programs, options.divisions);
  if (!access.allowedPrograms.length) {
    const roleCodes = new Set(context.activeRoleAssignments.map((item) => item.role_code));
    const needsPrimaryProgram =
      !context.profile.primary_program_id &&
      (roleCodes.has("professor") || roleCodes.has("peer_tutor"));
    return <section className="mx-auto max-w-4xl px-5 py-16">
      <h1 className="text-3xl font-bold">{needsPrimaryProgram ? "Programa académico requerido" : "No tienes permiso para crear actividades"}</h1>
      <p className="mt-4">{needsPrimaryProgram
        ? "Tu perfil no tiene un programa académico principal. Debes asignarlo antes de crear actividades."
        : context.profile.person_type === "student"
          ? "Tu cuenta está registrada como alumno. Necesitas una asignación institucional elegible para crear actividades."
          : "Tu cuenta está registrada, pero no tiene una asignación institucional elegible para crear actividades."}</p>
      <Link href="/activities" className="sitaa-text-action mt-7">Volver a actividades</Link>
    </section>;
  }

  const singleProgram = access.allowedPrograms.length === 1;
  return <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
    <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between"><div><p className="sitaa-section-eyebrow">Operación académica</p><h1 className="sitaa-section-title mt-3 text-3xl sm:text-4xl">Nueva actividad</h1><p className="sitaa-section-description mt-4">Registra la información base de la actividad.</p></div><Link href="/activities" className="sitaa-secondary-action px-6">Volver a actividades</Link></div>
    <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
      <ActivityForm options={options} access={access} today={getMexicoCityToday()} initialValues={{
        title: "", scope_type: "program", description: "",
        program_id: singleProgram ? access.allowedPrograms[0].id : "",
        activity_type_code: "", service_type_code: "", attention_category_code: "",
        modality_code: "", location_type_code: "", location_detail: "",
        start_date: "", start_time: "", duration_mode: "one_hour", end_date: "", end_time: "",
      }} />
    </div>
  </main>;
}
