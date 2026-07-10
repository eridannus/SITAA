import type { Metadata } from "next";
import Link from "next/link";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope, getActivityScopeAccess, isStudentOnlyUser } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { getActivityParticipants } from "@/lib/activities/get-activity-participants";
import { getActiveActivityAttendanceCheckin, getActivityAttendanceCheckinState, getActivityAttendanceDeadline, getActivityAttendanceOpenAt } from "@/lib/activities/get-attendance-checkin";
import { getVisibleActivities } from "@/lib/activities/get-visible-activities";
import { getMexicoCityToday } from "@/lib/activities/date-time";
import { finalizeExpiredAttendance } from "@/lib/attendance/finalize-expired-attendance";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { qrSvgDataUri } from "@/lib/qr/qr-code";
import type { Activity, ActivityFormOptions, ActivityFormValues } from "@/types/activities";
import type { ParticipantRole } from "@/types/catalogs";
import { ActivityForm } from "../new/activity-form";
import { DeleteActivityButton } from "./delete-activity-button";
import { AttendanceCheckinManager } from "./checkin/attendance-checkin-manager";
import { ParticipantManager } from "./participants/participant-manager";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = "force-no-store";
export const metadata: Metadata = { title: "Detalle de actividad" };
type Props = { params: Promise<{ id: string }>; searchParams: Promise<{ updated?: string | string[]; error?: string | string[]; participant?: string | string[]; checkin?: string | string[]; checkin_detail?: string | string[] }> };
const BASE_CORRECTION_ROLES = new Set(["program_tutoring_lead", "program_advising_lead", "program_head", "division_tutoring_liaison", "technical_admin"]);
const durationLabels = { one_hour: "1 hora", two_hours: "2 horas", custom: "Personalizada" } as const;

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
function catalogLabel<T extends { code: string; label?: string | null; name?: string | null }>(items: T[], code: string | null | undefined) {
  if (!code) return null;
  const item = items.find((entry) => entry.code === code);
  return item?.label?.trim() || item?.name?.trim() || code;
}

async function requestOrigin() {
  const configured = process.env.NEXT_PUBLIC_SITE_URL?.trim().replace(/\/$/, "");
  if (configured) return configured;
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host");
  const protocol = requestHeaders.get("x-forwarded-proto") ?? "http";
  return host ? protocol + "://" + host : "http://localhost:3000";
}

export default async function ActivityDetailPage({ params, searchParams }: Props) {
  const { id } = await params;
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");

  await finalizeExpiredAttendance();
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
  const hasBaseCorrectionRole = context.activeRoleAssignments.some((item) => BASE_CORRECTION_ROLES.has(item.role_code));
  const canUpdateBaseData = baseUpdatePermission.data === true;
  const canDeleteActivityRecord = deletePermission.data === true;
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
  const checkinStatus = param(query.checkin);
  const checkinDetail = param(query.checkin_detail);
  const responsibleName = card?.responsibleName || "Responsable no disponible";
  const programName = card?.programName || (activity.scope_type === "division" ? "Ambos programas" : options.programs.find((item) => item.id === activity.program_id)?.name ?? "Programa no disponible");
  const locationDetail = activity.location_detail?.trim();
  const locationHeading = card?.locationTypeLabel?.trim() || options.locationTypes.find((item) => item.code === activity.location_type_code)?.label?.trim() || options.locationTypes.find((item) => item.code === activity.location_type_code)?.name?.trim() || "Ubicación";
  const statusLabel = card?.statusLabel || catalogLabel(options.statuses, activity.status_code) || activity.status_code || "No especificado";
  const activityTypeLabel = card?.activityTypeLabel || catalogLabel(options.activityTypes, activity.activity_type_code);
  const serviceTypeLabel = card?.serviceTypeLabel || catalogLabel(options.serviceTypes, activity.service_type_code);
  const attentionCategoryLabel = card?.attentionCategoryLabel || catalogLabel(options.attentionCategories, activity.attention_category_code);
  const modalityLabel = card?.modalityLabel || catalogLabel(options.modalities, activity.modality_code);
  const showMissingPlaceholder = !studentOnly;
  const valueOrPlaceholder = (value: string | null | undefined) => value?.trim() || (showMissingPlaceholder ? "No especificado" : "");
  const durationLabel = activity.duration_mode ? durationLabels[activity.duration_mode] : null;
  const isPublished = activity.status_code !== "draft";
  const showAdministrativeCorrectionMode = canUpdateBaseData && hasBaseCorrectionRole && (activityHasEnded || isPublished);
  const contactMessage = activity.service_type_code === "tutoring"
    ? "Los datos base están bloqueados. Si necesitas corregirlos, contacta al encargado de tutorías de tu programa."
    : activity.service_type_code === "advising"
      ? "Los datos base están bloqueados. Si necesitas corregirlos, contacta al encargado de asesorías de tu programa."
      : "Los datos base están bloqueados. Si necesitas corregirlos, contacta al responsable correspondiente.";
  const baseDataLockMessage = `${activityHasEnded ? "Esta actividad ya ocurrió." : "Esta actividad ya fue publicada."} ${contactMessage} Puedes actualizar participantes y asistencia cuando corresponda.`;

  const [activeCheckinResult, checkinStateResult, checkinOpenAtResult, checkinDeadlineResult] = canManageParticipants
    ? await Promise.all([getActiveActivityAttendanceCheckin(id), getActivityAttendanceCheckinState(id), getActivityAttendanceOpenAt(id), getActivityAttendanceDeadline(id)])
    : [{ token: null, error: null }, { state: null, error: null }, { openAt: null }, { deadline: null, hasPassed: false }];
  const activeCheckinState = checkinStateResult.state;
  const attendanceOpenAt = checkinOpenAtResult.openAt;
  const attendanceDeadline = checkinDeadlineResult.deadline;
  const attendanceDeadlinePassed = checkinDeadlineResult.hasPassed;
  const activeCheckin = activeCheckinResult.token;
  const directCheckinLink = activeCheckin ? (await requestOrigin()) + "/check-in/" + encodeURIComponent(activeCheckin.secret_token) : null;
  const displayedCheckinStatus = activeCheckinResult.error || checkinStateResult.error ? "fetch-error" : checkinStatus;
  const displayedCheckinDetail = activeCheckinResult.error ?? checkinStateResult.error ?? checkinDetail;
  let qrDataUri: string | null = null;
  if (directCheckinLink) {
    try { qrDataUri = await qrSvgDataUri(directCheckinLink); }
    catch { qrDataUri = null; }
  }

  return <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
    <div className="flex min-w-0 flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
      <div className="min-w-0"><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Actividad</p><h1 className="mt-3 break-words text-3xl font-bold text-emerald-950 sm:text-4xl">{canUpdateBaseData ? "Editar actividad" : activity.title}</h1></div>
      <Link href="/activities" className="shrink-0 cursor-pointer rounded-full border border-slate-300 px-6 py-3 text-sm font-bold transition hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Volver a actividades</Link>
    </div>
    {updated && <div role="status" className="mt-8 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">Los cambios se guardaron correctamente.</div>}

    {canUpdateBaseData ? <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
      {showAdministrativeCorrectionMode && <div role="status" className="mb-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-semibold text-amber-900">Corrección administrativa de datos base habilitada.</div>}
      <ActivityForm options={options} access={access} initialValues={values} today={getMexicoCityToday()} mode="edit" activityId={id} statusCode={activity.status_code} />
    </div> : <section className="mt-9 min-w-0 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
      <h2 className="break-words text-2xl font-bold text-slate-900">{activity.title}</h2>
      {activity.description && <p className="mt-4 break-words leading-7 text-slate-600">{activity.description}</p>}
      <dl className="mt-6 grid min-w-0 gap-4 text-sm sm:grid-cols-2">
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Estado</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(statusLabel)}</dd></div>
        {!studentOnly && <div className="min-w-0"><dt className="font-semibold text-slate-500">Semestre</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(card?.academicPeriodLabel)}</dd></div>}
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Programa</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(programName)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Tipo de actividad</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(activityTypeLabel)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Tipo de servicio</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(serviceTypeLabel)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Categoría de atención</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(attentionCategoryLabel)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Modalidad</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(modalityLabel)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Tipo de ubicación</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(locationHeading)}</dd></div>
        <div className="min-w-0 sm:col-span-2"><dt className="break-words font-semibold text-slate-500">Detalle de ubicación</dt>{locationDetail ? (isHttpUrl(locationDetail) ? <dd className="mt-1 min-w-0 break-all text-slate-900"><a className="cursor-pointer text-slate-900 underline decoration-emerald-500 underline-offset-4 transition hover:text-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2" href={locationDetail} target="_blank" rel="noopener noreferrer">{locationDetail}</a></dd> : <dd className="mt-1 min-w-0 break-words text-slate-900">{locationDetail}</dd>) : <dd className="mt-1 min-w-0 break-words text-slate-900">{valueOrPlaceholder(null)}</dd>}</div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Fecha</dt><dd className="break-words text-slate-900">{activity.start_date ? date(activity.start_date) : valueOrPlaceholder(null)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Hora de inicio</dt><dd className="break-words text-slate-900">{activity.start_time?.slice(0,5) ?? valueOrPlaceholder(null)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Hora de término</dt><dd className="break-words text-slate-900">{activity.end_time?.slice(0,5) ?? valueOrPlaceholder(null)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Duración</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(durationLabel)}</dd></div>
        <div className="min-w-0"><dt className="font-semibold text-slate-500">Responsable</dt><dd className="break-words text-slate-900">{valueOrPlaceholder(responsibleName)}</dd></div>
      </dl>
      {studentOnly && <p className="mt-6 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-900">{card?.ownParticipantRoleLabel ? `Tu participación: ${card.ownParticipantRoleLabel}.` : "Estás registrado como participante en esta actividad."}</p>}
      {canManageActivity && !canUpdateBaseData && <p className="mt-6 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm font-semibold text-amber-900">{baseDataLockMessage}</p>}
      {!studentOnly && !canManageActivity && <p className="mt-6 rounded-xl bg-slate-50 p-4 text-sm text-slate-600">Puedes consultar este registro, pero tus asignaciones actuales no permiten editarlo ni eliminarlo.</p>}
    </section>}

    {canManageParticipants && <AttendanceCheckinManager activityId={id} token={activeCheckin} directLink={directCheckinLink} qrDataUri={qrDataUri} checkinState={activeCheckinState} attendanceOpenAt={attendanceOpenAt} attendanceDeadline={attendanceDeadline} attendanceDeadlinePassed={attendanceDeadlinePassed} status={displayedCheckinStatus} detail={displayedCheckinDetail} />}

    {canManageParticipants && (participantsError
      ? <section className="mt-10 rounded-3xl border border-red-200 bg-white p-7"><h2 className="text-xl font-bold">Participantes</h2><p className="mt-3 text-red-700">No fue posible cargar los participantes.</p></section>
      : <ParticipantManager activityId={id} participants={participants} roles={roles} canEdit status={participantStatus} attendanceWindowExpired={attendanceDeadlinePassed} />)}

    {canDeleteActivityRecord && <section className="mt-10 rounded-3xl border border-red-200 bg-red-50 p-7 sm:p-10"><h2 className="text-xl font-bold text-red-950">Eliminar actividad</h2><p className="mt-3 text-red-800">Esta acción elimina definitivamente el registro.</p>{deleteError && <p role="alert" className="mt-3 font-semibold text-red-800">No fue posible eliminar la actividad.</p>}<div className="mt-5"><DeleteActivityButton activityId={id} /></div></section>}
  </main>;
}




