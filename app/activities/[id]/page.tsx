import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope, getActivityScopeAccess, isStudentOnlyUser } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { getActivityParticipants } from "@/lib/activities/get-activity-participants";
import { getVisibleActivities } from "@/lib/activities/get-visible-activities";
import { getMexicoCityToday } from "@/lib/activities/date-time";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity, ActivityFormOptions, ActivityFormValues } from "@/types/activities";
import type { ParticipantRole } from "@/types/catalogs";
import { ActivityForm } from "../new/activity-form";
import { DeleteActivityButton } from "./delete-activity-button";
import { ParticipantManager } from "./participants/participant-manager";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Detalle de actividad" };
type Props = { params: Promise<{ id: string }>; searchParams: Promise<{ updated?: string | string[]; error?: string | string[]; participant?: string | string[] }> };

function formValues(activity: Activity): ActivityFormValues {
  return {
    title: activity.title ?? "", scope_type: activity.scope_type ?? "program", description: activity.description ?? "",
    program_id: activity.program_id ?? "", activity_type_code: activity.activity_type_code ?? "",
    service_type_code: activity.service_type_code ?? "", attention_category_code: activity.attention_category_code ?? "",
    modality_code: activity.modality_code ?? "", location_type_code: activity.location_type_code ?? "",
    location_detail: activity.location_detail ?? "", start_date: activity.start_date ?? "",
    start_time: activity.start_time?.slice(0, 5) ?? "", duration_mode: activity.duration_mode ?? "custom",
    end_date: activity.end_date ?? "", end_time: activity.end_time?.slice(0, 5) ?? "",
  };
}
function param(value: string | string[] | undefined) { return Array.isArray(value) ? value[0] : value; }
function date(value: string | null) {
  if (!value) return "No disponible";
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}
function isHttpUrl(value: string) {
  return value.startsWith("http://") || value.startsWith("https://");
}

export default async function ActivityDetailPage({ params, searchParams }: Props) {
  const { id } = await params;
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");

  const supabase = await createSupabaseServerClient();
  const [{ data, error }, cardsResult] = await Promise.all([
    supabase.from("activities").select("*").eq("id", id).maybeSingle(),
    getVisibleActivities().then((cards) => ({ cards, error: null })).catch(() => ({ cards: [], error: true })),
  ]);
  if (error || !data) return <main className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">Actividad no disponible</h1><p className="mt-4">La actividad no existe o tus permisos no permiten consultarla.</p><Link href="/activities" className="mt-7 inline-flex cursor-pointer font-bold text-emerald-800 transition hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Volver a actividades</Link></main>;

  const activity = data as Activity;
  let options: ActivityFormOptions;
  try { options = await getActivityFormOptions(); }
  catch { return <main className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible cargar la actividad</h1></main>; }

  const card = cardsResult.cards.find((item) => item.id === id);
  const values = formValues(activity);
  const studentOnly = isStudentOnlyUser(context);
  if (studentOnly && activity.status_code === "draft") return <main className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">Actividad no disponible</h1><p className="mt-4">La actividad no existe o tus permisos no permiten consultarla.</p><Link href="/activities" className="mt-7 inline-flex cursor-pointer font-bold text-emerald-800 transition hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Volver a actividades</Link></main>;
  const technicalAdmin = context.activeRoleAssignments.some((item) => item.role_code === "technical_admin");
  const legacyCleanup = activity.scope_type === "division" && (technicalAdmin || activity.created_by === context.user.id);
  const normalCanEdit = activity.scope_type === "program" && canManageActivityScope(context, values, options.programs, activity.division_id);
  const canManageActivity = !studentOnly && (normalCanEdit || legacyCleanup);
  const [baseUpdatePermission, deletePermission, endedResult] = await Promise.all([
    supabase.rpc("can_update_activity_base", { target_activity_id: id }),
    supabase.rpc("can_delete_activity", { target_activity_id: id }),
    supabase.rpc("activity_has_ended", { target_activity_id: id }),
  ]);
  const canUpdateBaseData = canManageActivity && baseUpdatePermission.data === true;
  const canDeleteActivityRecord = canManageActivity && deletePermission.data === true;
  const activityHasEnded = endedResult.data === true;
  const canManageParticipants = !studentOnly && normalCanEdit;

  let access = getActivityScopeAccess(context, options.programs, options.divisions);
  if (legacyCleanup && !technicalAdmin) {
    access = {
      ...access,
      allowedPrograms: options.programs.filter((program) => program.division_id === activity.division_id),
    };
  }

  let roles: ParticipantRole[] = [];
  let participants: Awaited<ReturnType<typeof getActivityParticipants>> = [];
  let participantsError = false;
  if (canManageParticipants) {
    const [rolesResult, participantResult] = await Promise.all([
      supabase.from("participant_roles").select("*").eq("is_active", true),
      getActivityParticipants(id).then((items) => ({ items, error: null })).catch(() => ({ items: [], error: true })),
    ]);
    roles = rolesResult.error ? [] : [...(rolesResult.data as ParticipantRole[])].sort((left, right) => (left.sort_order ?? 0) - (right.sort_order ?? 0));
    participants = participantResult.items;
    participantsError = Boolean(participantResult.error);
  }

  const query = await searchParams;
  const updated = param(query.updated) === "1";
  const deleteError = param(query.error) === "delete";
  const participantStatus = param(query.participant);
  const responsibleName = card?.responsibleName || "Responsable no disponible";
  const programName = card?.programName || (activity.scope_type === "division" ? "Ambos programas" : options.programs.find((item) => item.id === activity.program_id)?.name ?? "Programa no disponible");
  const locationDetail = activity.location_detail?.trim();
  const locationHeading = card?.locationTypeLabel?.trim() || options.locationTypes.find((item) => item.code === activity.location_type_code)?.label?.trim() || options.locationTypes.find((item) => item.code === activity.location_type_code)?.name?.trim() || "Ubicación";
  const isPublished = activity.status_code !== "draft";
  const baseDataLockMessage = activityHasEnded
    ? activity.service_type_code === "tutoring"
      ? "Esta actividad ya ocurri\u00f3. Los datos base est\u00e1n bloqueados. Si necesitas corregirlos, contacta al encargado de tutor\u00edas de tu programa."
      : activity.service_type_code === "advising"
        ? "Esta actividad ya ocurri\u00f3. Los datos base est\u00e1n bloqueados. Si necesitas corregirlos, contacta al encargado de asesor\u00edas de tu programa."
        : "Esta actividad ya ocurri\u00f3. Los datos base est\u00e1n bloqueados. Si necesitas corregirlos, contacta al responsable correspondiente."
    : "Esta actividad ya fue publicada. Los datos base est\u00e1n bloqueados; puedes actualizar participantes y asistencia.";

  return <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
    <div className="flex min-w-0 flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
      <div className="min-w-0"><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Actividad</p><h1 className="mt-3 break-words text-3xl font-bold text-emerald-950 sm:text-4xl">{canUpdateBaseData ? "Editar actividad" : activity.title}</h1></div>
      <Link href="/activities" className="shrink-0 cursor-pointer rounded-full border border-slate-300 px-6 py-3 text-sm font-bold transition hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Volver a actividades</Link>
    </div>
    {updated && <div role="status" className="mt-8 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">Los cambios se guardaron correctamente.</div>}

    {canUpdateBaseData ? <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
      {(activityHasEnded || isPublished) && <div role="status" className="mb-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-semibold text-amber-900">Corrección administrativa de datos base habilitada.</div>}
      <ActivityForm options={options} access={access} initialValues={values} today={getMexicoCityToday()} mode="edit" activityId={id} statusCode={activity.status_code} />
    </div> : <section className="mt-9 min-w-0 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
      <h2 className="break-words text-2xl font-bold text-slate-900">{activity.title}</h2>
      {activity.description && <p className="mt-4 break-words leading-7 text-slate-600">{activity.description}</p>}
      <dl className="mt-6 grid min-w-0 gap-4 text-sm sm:grid-cols-2">
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Fecha</dt><dd className="break-words text-slate-900">{date(activity.start_date)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Horario</dt><dd className="break-words text-slate-900">{activity.start_time?.slice(0,5) ?? "--:--"}–{activity.end_time?.slice(0,5) ?? "--:--"}</dd></div>
        {!studentOnly && <div className="min-w-0"><dt className="font-semibold text-slate-500">Semestre</dt><dd className="break-words text-slate-900">{card?.academicPeriodLabel ?? "Sin semestre asignado"}</dd></div>}
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Programa</dt><dd className="break-words text-slate-900">{programName}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Responsable</dt><dd className="break-words text-slate-900">{responsibleName}</dd></div>
        <div className="min-w-0 sm:col-span-2"><dt className="break-words font-semibold text-slate-500">{locationHeading}</dt>{locationDetail ? (isHttpUrl(locationDetail) ? <dd className="mt-1 min-w-0 break-all text-slate-900"><a className="cursor-pointer text-slate-900 underline decoration-emerald-500 underline-offset-4 transition hover:text-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2" href={locationDetail} target="_blank" rel="noopener noreferrer">{locationDetail}</a></dd> : <dd className="mt-1 min-w-0 break-words text-slate-900">{locationDetail}</dd>) : null}</div>
      </dl>
      {studentOnly && <p className="mt-6 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-900">{card?.ownParticipantRoleLabel ? `Tu participación: ${card.ownParticipantRoleLabel}.` : "Estás registrado como participante en esta actividad."}</p>}
      {canManageActivity && !canUpdateBaseData && <p className="mt-6 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm font-semibold text-amber-900">{baseDataLockMessage}</p>}
      {!studentOnly && !canManageActivity && <p className="mt-6 rounded-xl bg-slate-50 p-4 text-sm text-slate-600">Puedes consultar este registro, pero tus asignaciones actuales no permiten editarlo ni eliminarlo.</p>}
    </section>}

    {canManageParticipants && (participantsError
      ? <section className="mt-10 rounded-3xl border border-red-200 bg-white p-7"><h2 className="text-xl font-bold">Participantes</h2><p className="mt-3 text-red-700">No fue posible cargar los participantes.</p></section>
      : <ParticipantManager activityId={id} participants={participants} roles={roles} canEdit status={participantStatus} />)}

    {canDeleteActivityRecord && <section className="mt-10 rounded-3xl border border-red-200 bg-red-50 p-7 sm:p-10"><h2 className="text-xl font-bold text-red-950">Eliminar actividad</h2><p className="mt-3 text-red-800">Esta acción elimina definitivamente el registro.</p>{deleteError && <p role="alert" className="mt-3 font-semibold text-red-800">No fue posible eliminar la actividad.</p>}<div className="mt-5"><DeleteActivityButton activityId={id} /></div></section>}
  </main>;
}




