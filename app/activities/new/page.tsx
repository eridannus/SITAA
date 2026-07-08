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
        : "Tus asignaciones actuales no permiten crear actividades. Los usuarios con rol únicamente de alumno no tienen acceso a este registro."}</p>
      <Link href="/activities" className="mt-7 inline-flex font-bold text-emerald-800 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 transition hover:opacity-90">Volver a actividades</Link>
    </section>;
  }

  const singleProgram = access.allowedPrograms.length === 1;
  return <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
    <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between"><div><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Operación académica</p><h1 className="mt-3 text-3xl font-bold text-emerald-950 sm:text-4xl">Nueva actividad</h1><p className="mt-4 text-slate-600">Registra la información base de la actividad.</p></div><Link href="/activities" className="rounded-full border border-slate-300 px-6 py-3 text-sm font-bold cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 transition hover:opacity-90">Volver a actividades</Link></div>
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
