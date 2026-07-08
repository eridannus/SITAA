import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope, hasActivityCreationRole, isStudentOnlyUser } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { getVisibleActivities } from "@/lib/activities/get-visible-activities";
import type { ActivityFormValues, ActivityListItem } from "@/types/activities";

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
    activity_type_code: activity.activity_type_code,
    service_type_code: activity.service_type_code,
    attention_category_code: activity.attention_category_code ?? "",
    modality_code: activity.modality_code,
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

function ActivityCard({ activity, studentOnly }: { activity: ActivityListItem; studentOnly: boolean }) {
  const when = schedule(activity);
  const description = activity.description?.trim();
  const locationDetail = activity.location_detail?.trim();
  const locationHeading = activity.locationTypeLabel?.trim() || "Ubicación";
  const statusBadgeClass = activity.status_code === "draft" ? "border border-amber-300 bg-amber-100 text-amber-900" : "border border-emerald-300 bg-emerald-100 text-emerald-900";

  return (
    <article className="min-w-0 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition hover:border-emerald-300 sm:p-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0">
          <p className="break-words text-sm font-semibold text-emerald-700">{activity.activityTypeLabel}</p>
          <h2 className="mt-2 break-words text-xl font-bold text-slate-900">{activity.title}</h2>
          {description ? <p className="mt-3 break-words leading-7 text-slate-600">{description}</p> : null}
        </div>
        <span className={`w-fit rounded-full px-3 py-1 text-xs font-bold ${statusBadgeClass}`}>{activity.statusLabel}</span>
      </div>

      <dl className="mt-6 grid min-w-0 gap-4 border-t border-slate-100 pt-6 text-sm sm:grid-cols-2">
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
        {(activity.locationTypeLabel || locationDetail) ? (
          <div className="min-w-0 sm:col-span-2">
            <dt className="break-words font-semibold text-slate-500">{locationHeading}</dt>
            {locationDetail ? (
              isHttpUrl(locationDetail) ? (
                <dd className="mt-1 min-w-0 break-all text-slate-900">
                  <a className="cursor-pointer text-slate-900 underline decoration-emerald-500 underline-offset-4 transition hover:text-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2" href={locationDetail} target="_blank" rel="noopener noreferrer">
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
        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center">
          <p className="inline-flex w-fit rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-700">
            Actividad asignada
          </p>
          {activity.viewerAttendanceStatus ? <p className="text-sm font-semibold text-slate-700">Asistencia: {attendanceStatusLabels[activity.viewerAttendanceStatus]}</p> : null}
        </div>
      ) : (
        <Link href={`/activities/${activity.id}`} className="mt-6 inline-flex cursor-pointer text-sm font-bold text-emerald-800 hover:text-emerald-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
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
  const canCreate = hasActivityCreationRole(context);
  const studentOnly = isStudentOnlyUser(context);

  let activities: ActivityListItem[];
  try {
    const [visibleActivities, options] = await Promise.all([
      getVisibleActivities(),
      getActivityFormOptions(),
    ]);
    const technicalAdmin = context.activeRoleAssignments.some((item) => item.role_code === "technical_admin");
    activities = visibleActivities.filter((activity) => !studentOnly || activity.status_code !== "draft").map((activity) => ({
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
        <div><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Operación académica</p><h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">Actividades</h1></div>
        {canCreate && <Link href="/activities/new" className="rounded-full bg-emerald-800 px-6 py-3 text-center text-sm font-bold text-white transition hover:bg-emerald-900 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Nueva actividad</Link>}
      </div>
      {(created || deleted) && <div role="status" className="mt-8 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{created ? "La actividad se creó correctamente." : "La actividad se eliminó correctamente."}</div>}
      {activities.length === 0 ? <div className="mt-10 rounded-3xl border border-dashed border-slate-300 bg-white p-10 text-center"><h2 className="text-xl font-bold text-slate-900">Aún no hay actividades visibles</h2><p className="mt-3 text-slate-600">{canCreate ? "Crea una actividad o espera a que te asignen acceso a una existente." : "Aún no tienes actividades asignadas. Cuando seas agregado como participante, aparecerán aquí."}</p></div> : <div className="mt-10 grid gap-6 lg:grid-cols-2">{activities.map((activity) => <ActivityCard key={activity.id} activity={activity} studentOnly={studentOnly} />)}</div>}
    </main>
  );
}



