"use client";

import { useActionState, useEffect, useMemo, useState } from "react";
import { useFormStatus } from "react-dom";
import { createActivity, resolveAcademicSemester, updateActivity } from "@/app/activities/actions";
import { calculatePresetEnd } from "@/lib/activities/date-time";
import type { ActivityFormOptions, ActivityFormState, ActivityFormValues, ActivityScopeAccess, DurationMode } from "@/types/activities";
import type { CatalogRow } from "@/types/catalogs";

interface Props {
  options: ActivityFormOptions;
  access: ActivityScopeAccess;
  initialValues: ActivityFormValues;
  today: string;
  mode?: "create" | "edit";
  activityId?: string;
}
function label(item: CatalogRow) { return item.label?.trim() || item.name?.trim() || item.code; }
function displayDate(value: string) {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}
function FieldError({ message }: { message?: string }) {
  return message ? <p className="mt-2 text-sm font-medium text-red-700">{message}</p> : null;
}
function SubmitButton({ mode }: { mode: "create" | "edit" }) {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} className="rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 disabled:cursor-not-allowed disabled:bg-slate-400 focus:outline-none focus:ring-4 focus:ring-emerald-200 cursor-pointer disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
    {pending ? (mode === "edit" ? "Guardando…" : "Creando…") : (mode === "edit" ? "Guardar cambios" : "Crear actividad")}
  </button>;
}

export function ActivityForm({ options, access, initialValues, today, mode = "create", activityId }: Props) {
  const action = mode === "edit" && activityId ? updateActivity.bind(null, activityId) : createActivity;
  const [state, formAction] = useActionState<ActivityFormState, FormData>(action, { revision: 0, values: initialValues, errors: {}, message: null });
  return <form action={formAction} className="grid gap-6 sm:grid-cols-2" noValidate>
    <Fields key={state.revision} state={state} options={options} access={access} today={today} mode={mode} />
  </form>;
}

function Fields({ state, options, access, today, mode }: {
  state: ActivityFormState; options: ActivityFormOptions; access: ActivityScopeAccess;
  today: string; mode: "create" | "edit";
}) {
  const [liveValues, setLiveValues] = useState(state.values);
  const calculatedEnd = useMemo(
    () => calculatePresetEnd(liveValues.start_date, liveValues.start_time, liveValues.duration_mode as DurationMode),
    [liveValues.duration_mode, liveValues.start_date, liveValues.start_time],
  );
  const [resolvedSemester, setResolvedSemester] = useState<{
    date: string;
    label: string | null;
    error: boolean;
  } | null>(null);
  useEffect(() => {
    let cancelled = false;
    if (liveValues.start_date) {
      resolveAcademicSemester(liveValues.start_date).then((result) => {
        if (cancelled) return;
        setResolvedSemester({ date: liveValues.start_date, label: result.label, error: result.error });
      });
    }
    return () => { cancelled = true; };
  }, [liveValues.start_date]);
  const semesterInfo = useMemo(() => {
    if (!liveValues.start_date) {
      return { tone: "neutral" as const, text: "Selecciona una fecha de inicio para asignar el semestre." };
    }
    if (!resolvedSemester || resolvedSemester.date !== liveValues.start_date) {
      return { tone: "neutral" as const, text: "Consultando semestre..." };
    }
    if (resolvedSemester.error || !resolvedSemester.label) {
      return { tone: "warning" as const, text: "No hay semestre registrado para esta fecha." };
    }
    return { tone: "ok" as const, text: "Semestre: " + resolvedSemester.label };
  }, [liveValues.start_date, resolvedSemester]);
  const set = (field: keyof ActivityFormValues, value: string) => setLiveValues((current) => ({ ...current, [field]: value }));
  const inputClass = (field: keyof ActivityFormValues) => `mt-2 w-full rounded-xl border bg-white px-4 py-3 text-slate-900 outline-none transition focus:ring-4 ${state.errors[field] ? "border-red-400 focus:border-red-600 focus:ring-red-100" : "border-slate-300 focus:border-emerald-700 focus:ring-emerald-100"}`;
  const common = (field: keyof ActivityFormValues) => ({
    key: state.revision + ":" + field, defaultValue: state.values[field],
    onChange: (event: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => set(field, event.target.value),
    "aria-invalid": Boolean(state.errors[field]), className: inputClass(field),
  });
  const catalogSelect = (id: keyof ActivityFormValues, title: string, empty: string, items: CatalogRow[]) => <div>
    <label htmlFor={id} className="block text-sm font-semibold text-slate-700">{title}</label>
    <select id={id} name={id} required {...common(id)}><option value="">{empty}</option>{items.map((item) => <option key={item.id} value={item.code}>{label(item)}</option>)}</select>
    <FieldError message={state.errors[id]} />
  </div>;

  return <>
    {state.message && <div role="alert" className="sm:col-span-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800"><p className="font-semibold">Revisa los campos señalados.</p><p>{state.message}</p></div>}
    <div className={`sm:col-span-2 rounded-2xl border p-5 ${semesterInfo.tone === "warning" ? "border-amber-200 bg-amber-50 text-amber-900" : "border-emerald-200 bg-emerald-50 text-emerald-950"}`}><p className="text-sm font-semibold">{semesterInfo.text}</p><FieldError message={state.errors.academic_period_id} /></div>
    <div className="sm:col-span-2"><label htmlFor="title" className="block text-sm font-semibold text-slate-700">Título</label><input id="title" name="title" required maxLength={200} {...common("title")} /><FieldError message={state.errors.title} /></div>
    <div className="sm:col-span-2"><label htmlFor="description" className="block text-sm font-semibold text-slate-700">Descripción (opcional)</label><textarea id="description" name="description" rows={4} maxLength={5000} {...common("description")} /><FieldError message={state.errors.description} /></div>

    {access.allowedPrograms.length === 1 ? <>
      <input type="hidden" name="scope_type" value="program" />
      <input type="hidden" name="program_id" value={access.allowedPrograms[0].id} />
      <div className="sm:col-span-2 rounded-xl border border-slate-200 bg-slate-50 px-5 py-4">
        <p className="text-sm font-semibold text-slate-500">Programa académico</p>
        <p className="mt-1 font-bold text-slate-900">{access.allowedPrograms[0].name}</p>
      </div>
    </> : <>
      <input type="hidden" name="scope_type" value="program" />
      <div className="sm:col-span-2">
        <label htmlFor="program_id" className="block text-sm font-semibold text-slate-700">Programa académico</label>
        <select id="program_id" name="program_id" required {...common("program_id")}>
          <option value="">Selecciona un programa</option>
          {access.allowedPrograms.map((program) => <option key={program.id} value={program.id}>{program.name}</option>)}
        </select>
        <FieldError message={state.errors.program_id} />
      </div>
    </>}

    {catalogSelect("activity_type_code", "Tipo de actividad", "Selecciona un tipo", options.activityTypes)}
    {catalogSelect("service_type_code", "Tipo de servicio", "Selecciona un servicio", options.serviceTypes)}
    {catalogSelect("attention_category_code", "Categoría de atención", "Selecciona una categoría", options.attentionCategories)}
    {catalogSelect("modality_code", "Modalidad", "Selecciona una modalidad", options.modalities)}
    {catalogSelect("location_type_code", "Tipo de ubicación", "Selecciona un tipo de ubicación", options.locationTypes)}
    <div><label htmlFor="location_detail" className="block text-sm font-semibold text-slate-700">Detalle de ubicación</label><input id="location_detail" name="location_detail" required maxLength={500} placeholder="Aula, edificio o enlace" {...common("location_detail")} /><FieldError message={state.errors.location_detail} /></div>
    <div><label htmlFor="start_date" className="block text-sm font-semibold text-slate-700">Fecha de inicio</label><input id="start_date" name="start_date" type="date" required min={mode === "create" ? today : undefined} {...common("start_date")} /><FieldError message={state.errors.start_date} /></div>
    <div><label htmlFor="start_time" className="block text-sm font-semibold text-slate-700">Hora de inicio</label><input id="start_time" name="start_time" type="time" required step={60} lang="es-MX" {...common("start_time")} /><div className="mt-2 text-xs text-slate-500"><p>Usa formato de 24 horas.</p><p>Ejemplo: 14:30.</p></div><FieldError message={state.errors.start_time} /></div>
    <div className="sm:col-span-2"><label htmlFor="duration_mode" className="block text-sm font-semibold text-slate-700">Duración</label><select id="duration_mode" name="duration_mode" required {...common("duration_mode")}><option value="one_hour">1 hora</option><option value="two_hours">2 horas</option><option value="custom">Personalizada</option></select><FieldError message={state.errors.duration_mode} /></div>
    {liveValues.duration_mode === "custom" ? <>
      <div><label htmlFor="end_date" className="block text-sm font-semibold text-slate-700">Fecha de término</label><input id="end_date" name="end_date" type="date" required min={liveValues.start_date || today} {...common("end_date")} /><FieldError message={state.errors.end_date} /></div>
      <div><label htmlFor="end_time" className="block text-sm font-semibold text-slate-700">Hora de término</label><input id="end_time" name="end_time" type="time" required step={60} lang="es-MX" {...common("end_time")} /><div className="mt-2 text-xs text-slate-500"><p>Usa formato de 24 horas.</p><p>Ejemplo: 14:30.</p></div><FieldError message={state.errors.end_time} /></div>
    </> : <div className="sm:col-span-2 rounded-xl bg-slate-50 px-4 py-4 text-sm text-slate-700"><span className="font-semibold">Término calculado: </span>{calculatedEnd ? `${displayDate(calculatedEnd.endDate)} a las ${calculatedEnd.endTime}` : "Indica fecha y hora de inicio para calcularlo."}</div>}
    <div className="sm:col-span-2 pt-2"><SubmitButton mode={mode} /></div>
  </>;
}
