import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope, hasActivityCreationRole, isStudentOnlyUser } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { getVisibleActivities } from "@/lib/activities/get-visible-activities";
import { finalizeExpiredAttendance } from "@/lib/attendance/finalize-expired-attendance";
import type { ActivityFormValues, ActivityListItem } from "@/types/activities";
import { Alert } from "@/components/ui/alert";
import { SectionHeading } from "@/components/ui/section-heading";
import { StatusBadge, type StatusTone } from "@/components/ui/status-badge";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Actividades" };
type Props = { searchParams: Promise<{ created?: string | string[]; deleted?: string | string[] }> };
const durationLabels = { one_hour: "1 hora", two_hours: "2 horas", custom: "Personalizada" } as const;
const attendanceStatusLabels = { pending: "Pendiente", attended: "Asistió", absent: "No asistió", justified: "Justificada" } as const;

function formatDate(value: string | null) {
  if (!value) return "Fecha no disponible";
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function formatTime(value: string | null) {
  return value ? value.slice(0, 5) : "--:--";
}

function schedule(activity: ActivityListItem) {
  if (activity.start_date && activity.start_time && activity.end_date && activity.end_time) {
    return {
      dates: activity.start_date === activity.end_date ? formatDate(activity.start_date) : `${formatDate(activity.start_date)} → ${formatDate(activity.end_date)}`,
      times: `${formatTime(activity.start_time)}–${formatTime(activity.end_time)}`,
      duration: activity.duration_mode ? durationLabels[activity.duration_mode] : "Duración no especificada",
    };
  }
  return { dates: "Fecha no disponible", times: "--:--", duration: "Duración no especificada" };
}

function permissionValues(activity: ActivityListItem): ActivityFormValues {
  return {
    title: activity.title,
    scope_type: activity.scope_type,
    description: activity.description ?? "",
    program_id: activity.program_id ?? "",
    activity_type_code: activity.activity_type_code ?? "",
    service_type_code: activity.service_type_code ?? "",
    attention_category_code: activity.attention_category_code ?? "",
    modality_code: activity.modality_code ?? "",
    location_type_code: activity.location_type_code ?? "",
    location_detail: activity.location_detail ?? "",
    start_date: activity.start_date ?? "",
    start_time: activity.start_time ?? "",
    duration_mode: activity.duration_mode ?? "custom",
    end_date: activity.end_date ?? "",
    end_time: activity.end_time ?? "",
  };
}

function isHttpUrl(value: string) {
  return value.startsWith("http://") || value.startsWith("https://");
}

function normalizedLabel(value: string | null | undefined) {
  return value?.normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase() ?? "";
}

function serviceIndicator(activity: ActivityListItem) {
  const code = normalizedLabel(activity.service_type_code);
  const label = normalizedLabel(activity.serviceTypeLabel);
  if (code === "tutoring" || label === "tutoria") return { text: "TUT", label: "Tutor\u00eda" };
  if (code === "advising" || label === "asesoria") return { text: "ASE", label: "Asesor\u00eda" };
  return null;
}

function programIndicator(activity: ActivityListItem) {
  const label = normalizedLabel(activity.programName);
  if (label === "diseno grafico" || label.includes("grafico")) return { text: "\u270e", label: "Dise\u00f1o Gr\u00e1fico" };
  if (label === "arquitectura" || label.includes("arquitectura")) return { text: "\u25b3", label: "Arquitectura" };
  return null;
}

function activityStatusTone(statusCode: string): StatusTone {
  if (statusCode === "scheduled") return "info";
  if (statusCode === "validated") return "success";
  if (statusCode === "cancelled") return "error";
  return "neutral";
}

function ActivityCard({ activity, studentOnly }: { activity: ActivityListItem; studentOnly: boolean }) {
  const when = schedule(activity);
  const description = activity.description?.trim();
  const locationDetail = activity.location_detail?.trim();
  const rawLocationHeading = activity.locationTypeLabel?.trim() || "Ubicación";
  const repeatsOnlineLabel = normalizedLabel(activity.modalityLabel) === "en linea" && normalizedLabel(rawLocationHeading) === "en linea";
  const locationHeading = repeatsOnlineLabel ? "Acceso" : rawLocationHeading;
  const shouldRenderLocation = Boolean(locationDetail || (!repeatsOnlineLabel && activity.locationTypeLabel));
  const service = serviceIndicator(activity);
  const program = programIndicator(activity);

  return (
    <article className="sitaa-card flex min-w-0 flex-col p-6 transition hover:border-[var(--sitaa-info-border)] sm:p-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0">
          <p className="break-words text-sm font-semibold text-[var(--sitaa-blue)]">{activity.activityTypeLabel}</p>
          <h2 className="mt-2 break-words text-xl font-bold text-slate-900">{activity.title}</h2>
          {description ? <p className="mt-3 break-words leading-7 text-slate-600">{description}</p> : null}
        </div>
        <div className="flex shrink-0 flex-col items-start gap-2 sm:items-end">
          <StatusBadge tone={activityStatusTone(activity.status_code)}>{activity.statusLabel}</StatusBadge>
          {(service || program) ? (
            <div className="flex items-center gap-2 text-xs font-semibold text-slate-500" aria-label="Indicadores de actividad">
              {service ? <span title={service.label} aria-label={service.label} className="rounded-full border border-slate-200 px-2 py-0.5 tracking-wide">{service.text}</span> : null}
              {program ? <span title={program.label} aria-label={program.label} className="px-1 text-sm leading-none">{program.text}</span> : null}
            </div>
          ) : null}
        </div>
      </div>

      <dl className="mt-6 grid min-w-0 flex-1 gap-4 border-t border-slate-100 pt-6 text-sm sm:grid-cols-2">
        <div className="min-w-0">
          <dt className="font-semibold text-slate-500">Fecha</dt>
          <dd className="mt-1 min-w-0 break-words text-slate-900">{when.dates}</dd>
        </div>
        <div className="min-w-0">
          <dt className="font-semibold text-slate-500">Horario (24 horas)</dt>
          <dd className="mt-1 min-w-0 break-words text-slate-900">{when.times}</dd>
        </div>
        {!studentOnly ? (
          <div className="min-w-0">
            <dt className="font-semibold text-slate-500">Semestre</dt>
            <dd className="mt-1 min-w-0 break-words text-slate-900">{activity.academicPeriodLabel ?? "Sin semestre asignado"}</dd>
          </div>
        ) : null}
        <div className="min-w-0">
          <dt className="font-semibold text-slate-500">Duración</dt>
          <dd className="mt-1 min-w-0 break-words text-slate-900">{when.duration}</dd>
        </div>
        <div className="min-w-0">
          <dt className="font-semibold text-slate-500">Programa</dt>
          <dd className="mt-1 min-w-0 break-words text-slate-900">{activity.programName}</dd>
        </div>
        <div className="min-w-0">
          <dt className="font-semibold text-slate-500">Servicio y modalidad</dt>
          <dd className="mt-1 min-w-0 break-words text-slate-900">{activity.serviceTypeLabel} · {activity.modalityLabel}</dd>
        </div>
        <div className="min-w-0">
          <dt className="font-semibold text-slate-500">Responsable</dt>
          <dd className="mt-1 min-w-0 break-words text-slate-900">{activity.responsibleName}</dd>
        </div>
        {shouldRenderLocation ? (
          <div className="min-w-0 sm:col-span-2">
            <dt className="break-words font-semibold text-slate-500">{locationHeading}</dt>
            {locationDetail ? (
              isHttpUrl(locationDetail) ? (
                <dd className="mt-1 min-w-0 break-all text-slate-900">
                  <a className="sitaa-text-action break-all" href={locationDetail} target="_blank" rel="noopener noreferrer">
                    {locationDetail}
                  </a>
                </dd>
              ) : (
                <dd className="mt-1 min-w-0 break-words text-slate-900">{locationDetail}</dd>
              )
            ) : null}
          </div>
        ) : null}
      </dl>

      {studentOnly ? (
        <div className="mt-auto flex flex-col gap-4 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <div className="min-w-0 space-y-3">
            <p className="inline-flex w-fit rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-700">
              Actividad asignada
            </p>
            {activity.viewerAttendanceStatus ? <p className="text-sm font-semibold text-slate-700">Asistencia: {attendanceStatusLabels[activity.viewerAttendanceStatus]}</p> : null}
          </div>
          {activity.isParticipant && activity.viewerAttendanceStatus === "pending" ? (
            <Link href="/check-in?from=activities" className="sitaa-primary-action w-full px-6 py-4 sm:ml-auto sm:w-auto">
              Registrar asistencia
            </Link>
          ) : null}
        </div>
      ) : (
        <Link href={`/activities/${activity.id}`} className="sitaa-text-action mt-auto pt-6">
          {activity.canEdit ? "Ver y editar →" : "Ver actividad →"}
        </Link>
      )}
    </article>
  );
}

export default async function ActivitiesPage({ searchParams }: Props) {
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");
  if (context.error) return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible cargar las actividades</h1><p className="mt-4">Intenta nuevamente más tarde.</p></section>;
  if (!context.profile) return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">Necesitas un perfil activo en SITAA</h1><p className="mt-4">Tu cuenta existe, pero aún no tiene un perfil institucional habilitado.</p></section>;
  await finalizeExpiredAttendance();
  const canCreate = hasActivityCreationRole(context);
  const studentOnly = isStudentOnlyUser(context);

  let activities: ActivityListItem[];
  try {
    const [visibleActivities, options] = await Promise.all([
      getVisibleActivities(),
      getActivityFormOptions(),
    ]);
    const technicalAdmin = context.activeRoleAssignments.some((item) => item.role_code === "technical_admin");
    activities = visibleActivities.filter((activity) => activity.status_code !== "draft" || (!studentOnly && activity.created_by === context.user.id)).map((activity) => ({
      ...activity,
      canEdit: activity.canEdit || (
        !studentOnly &&
        (
          (activity.scope_type === "program" &&
            canManageActivityScope(context, permissionValues(activity), options.programs, activity.division_id)) ||
          (activity.scope_type === "division" && (technicalAdmin || activity.created_by === context.user.id))
        )
      ),
    }));
  }
  catch { return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible cargar las actividades</h1><p className="mt-4">Intenta nuevamente más tarde.</p></section>; }

  const query = await searchParams;
  const created = (Array.isArray(query.created) ? query.created[0] : query.created) === "1";
  const deleted = (Array.isArray(query.deleted) ? query.deleted[0] : query.deleted) === "1";
  return (
    <main className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
        <SectionHeading eyebrow="Operación académica" title="Actividades" />
        {canCreate && <Link href="/activities/new" className="sitaa-primary-action px-6">Nueva actividad</Link>}
      </div>
      {(created || deleted) && <Alert tone="success" role="status" className="mt-8">{created ? "La actividad se creó correctamente." : "La actividad se eliminó correctamente."}</Alert>}
      {activities.length === 0 ? <div className="sitaa-empty-state mt-10 text-center"><h2 className="text-xl font-bold text-[var(--sitaa-text)]">Aún no hay actividades visibles</h2><p className="mt-3 text-[var(--sitaa-text-secondary)]">{canCreate ? "Crea una actividad o espera a que te asignen acceso a una existente." : "Aún no tienes actividades asignadas. Cuando seas agregado como participante, aparecerán aquí."}</p></div> : <div className="mt-10 grid gap-6 lg:grid-cols-2">{activities.map((activity) => <ActivityCard key={activity.id} activity={activity} studentOnly={studentOnly} />)}</div>}
    </main>
  );
}

