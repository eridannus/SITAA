import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope, getActivityScopeAccess } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { getMexicoCityToday } from "@/lib/activities/date-time";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity, ActivityFormOptions, ActivityFormValues } from "@/types/activities";
import { ActivityForm } from "../new/activity-form";
import { DeleteActivityButton } from "./delete-activity-button";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Editar actividad" };
type Props = { params: Promise<{ id: string }>; searchParams: Promise<{ updated?: string | string[]; error?: string | string[] }> };

function formValues(activity: Activity): ActivityFormValues {
  return {
    title: activity.title ?? "", scope_type: activity.scope_type ?? "program",
    description: activity.description ?? "", program_id: activity.program_id ?? "",
    activity_type_code: activity.activity_type_code ?? "", service_type_code: activity.service_type_code ?? "",
    attention_category_code: activity.attention_category_code ?? "", modality_code: activity.modality_code ?? "",
    location_type_code: activity.location_type_code ?? "", location_detail: activity.location_detail ?? "",
    start_date: activity.start_date ?? "", start_time: activity.start_time?.slice(0, 5) ?? "",
    duration_mode: activity.duration_mode ?? "custom", end_date: activity.end_date ?? "", end_time: activity.end_time?.slice(0, 5) ?? "",
  };
}

export default async function ActivityDetailPage({ params, searchParams }: Props) {
  const { id } = await params;
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("activities").select("*").eq("id", id).maybeSingle();
  if (error || !data) return <main className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">Actividad no disponible</h1><p className="mt-4">La actividad no existe o tus permisos no permiten consultarla.</p><Link href="/activities" className="mt-7 inline-flex font-bold text-emerald-800">Volver a actividades</Link></main>;

  let options: ActivityFormOptions;
  try { options = await getActivityFormOptions(); }
  catch { return <main className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible cargar el formulario</h1></main>; }
  if (options.academicPeriods.length !== 1) return <main className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No es posible editar la actividad</h1><p className="mt-4">Debe existir exactamente un periodo académico activo.</p></main>;

  const activity = data as Activity;
  const values = formValues(activity);
  const access = getActivityScopeAccess(context, options.programs, options.divisions);
  const canEdit = canManageActivityScope(context, values, options.programs, activity.division_id);
  if (!canEdit) return <main className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">Consulta de actividad</h1><p className="mt-4">Puedes consultar este registro, pero tus asignaciones actuales no permiten editarlo ni eliminarlo.</p><Link href="/activities" className="mt-7 inline-flex font-bold text-emerald-800">Volver a actividades</Link></main>;

  const query = await searchParams;
  const updated = (Array.isArray(query.updated) ? query.updated[0] : query.updated) === "1";
  const deleteError = (Array.isArray(query.error) ? query.error[0] : query.error) === "delete";
  return <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
    <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between"><div><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Actividad</p><h1 className="mt-3 text-3xl font-bold text-emerald-950 sm:text-4xl">Editar actividad</h1></div><Link href="/activities" className="rounded-full border border-slate-300 px-6 py-3 text-sm font-bold">Volver a actividades</Link></div>
    {updated && <div role="status" className="mt-8 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">Los cambios se guardaron correctamente.</div>}
    <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10"><ActivityForm options={options} access={access} activePeriod={options.academicPeriods[0]} initialValues={values} today={getMexicoCityToday()} mode="edit" activityId={id} /></div>
    <section className="mt-10 rounded-3xl border border-red-200 bg-red-50 p-7 sm:p-10"><h2 className="text-xl font-bold text-red-950">Eliminar actividad</h2><p className="mt-3 text-red-800">Esta acción elimina definitivamente el registro.</p>{deleteError && <p role="alert" className="mt-3 font-semibold text-red-800">No fue posible eliminar la actividad.</p>}<div className="mt-5"><DeleteActivityButton activityId={id} /></div></section>
  </main>;
}
