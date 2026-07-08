import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { hasActivityCreationRole } from "@/lib/activities/activity-scope-permissions";
import { getVisibleActivities } from "@/lib/activities/get-visible-activities";
import type { ActivityListItem } from "@/types/activities";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Actividades" };
type Props = { searchParams: Promise<{ created?: string | string[]; deleted?: string | string[] }> };
const durationLabels = { one_hour: "1 hora", two_hours: "2 horas", custom: "Personalizada" } as const;

function formatDate(value: string | null) {
  if (!value) return "Fecha no disponible";
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}
function formatTime(value: string | null) { return value ? value.slice(0, 5) : "--:--"; }
function schedule(activity: ActivityListItem) {
  if (activity.start_date && activity.start_time && activity.end_date && activity.end_time) return {
    dates: activity.start_date === activity.end_date ? formatDate(activity.start_date) : `${formatDate(activity.start_date)} → ${formatDate(activity.end_date)}`,
    times: `${formatTime(activity.start_time)}–${formatTime(activity.end_time)}`,
    duration: activity.duration_mode ? durationLabels[activity.duration_mode] : "Duración no especificada",
  };
  return { dates: "Fecha no disponible", times: "--:--", duration: "Duración no especificada" };
}

function ActivityCard({ activity }: { activity: ActivityListItem }) {
  const when = schedule(activity);
  return (
    <article className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition hover:border-emerald-300 sm:p-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div><p className="text-sm font-semibold text-emerald-700">{activity.activityTypeLabel}</p><h2 className="mt-2 text-xl font-bold text-slate-900">{activity.title}</h2>{activity.description && <p className="mt-3 line-clamp-3 leading-7 text-slate-600">{activity.description}</p>}</div>
        <span className="w-fit rounded-full bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-800">{activity.statusLabel}</span>
      </div>
      <dl className="mt-6 grid gap-4 border-t border-slate-100 pt-6 text-sm sm:grid-cols-2">
        <div><dt className="font-semibold text-slate-500">Fecha</dt><dd className="mt-1 text-slate-900">{when.dates}</dd></div>
        <div><dt className="font-semibold text-slate-500">Horario (24 horas)</dt><dd className="mt-1 text-slate-900">{when.times}</dd></div>
        <div><dt className="font-semibold text-slate-500">Duración</dt><dd className="mt-1 text-slate-900">{when.duration}</dd></div>
        <div><dt className="font-semibold text-slate-500">Programa</dt><dd className="mt-1 text-slate-900">{activity.programName}</dd></div>
        <div><dt className="font-semibold text-slate-500">Servicio y modalidad</dt><dd className="mt-1 text-slate-900">{activity.serviceTypeLabel} · {activity.modalityLabel}</dd></div>
        <div><dt className="font-semibold text-slate-500">Responsable</dt><dd className="mt-1 text-slate-900">{activity.responsibleName}</dd></div>
      </dl>
      <Link href={`/activities/${activity.id}`} className="mt-6 inline-flex text-sm font-bold text-emerald-800 hover:text-emerald-950">Ver y editar →</Link>
    </article>
  );
}

export default async function ActivitiesPage({ searchParams }: Props) {
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");
  if (context.error) return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible cargar las actividades</h1><p className="mt-4">Intenta nuevamente más tarde.</p></section>;
  if (!context.profile) return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">Necesitas un perfil activo en SITAA</h1><p className="mt-4">Tu cuenta existe, pero aún no tiene un perfil institucional habilitado.</p></section>;
  const canCreate = hasActivityCreationRole(context);

  let activities: ActivityListItem[];
  try { activities = await getVisibleActivities(); }
  catch { return <section className="mx-auto max-w-4xl px-5 py-16"><h1 className="text-3xl font-bold">No fue posible cargar las actividades</h1><p className="mt-4">Intenta nuevamente más tarde.</p></section>; }

  const query = await searchParams;
  const created = (Array.isArray(query.created) ? query.created[0] : query.created) === "1";
  const deleted = (Array.isArray(query.deleted) ? query.deleted[0] : query.deleted) === "1";
  return (
    <main className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
        <div><p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Operación académica</p><h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">Actividades</h1><p className="mt-4 max-w-2xl leading-7 text-slate-600">Consulta las actividades que tus permisos actuales te permiten ver.</p></div>
        {canCreate && <Link href="/activities/new" className="rounded-full bg-emerald-800 px-6 py-3 text-center text-sm font-bold text-white transition hover:bg-emerald-900">Nueva actividad</Link>}
      </div>
      {(created || deleted) && <div role="status" className="mt-8 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{created ? "La actividad se creó correctamente." : "La actividad se eliminó correctamente."}</div>}
      {activities.length === 0 ? <div className="mt-10 rounded-3xl border border-dashed border-slate-300 bg-white p-10 text-center"><h2 className="text-xl font-bold text-slate-900">Aún no hay actividades visibles</h2><p className="mt-3 text-slate-600">Crea una actividad o espera a que te asignen acceso a una existente.</p></div> : <div className="mt-10 grid gap-6 lg:grid-cols-2">{activities.map((activity) => <ActivityCard key={activity.id} activity={activity} />)}</div>}
    </main>
  );
}
