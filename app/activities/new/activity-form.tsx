"use client";

import { useActionState, useMemo, useState } from "react";
import { useFormStatus } from "react-dom";
import { createActivity, updateActivity } from "@/app/activities/actions";
import { calculatePresetEnd } from "@/lib/activities/date-time";
import type { ActivityFormOptions, ActivityFormState, ActivityFormValues, DurationMode } from "@/types/activities";
import type { AcademicPeriod, CatalogRow } from "@/types/catalogs";

interface Props {
  options: ActivityFormOptions;
  activePeriod: AcademicPeriod;
  initialValues: ActivityFormValues;
  today: string;
  mode?: "create" | "edit";
  activityId?: string;
}

function label(item: CatalogRow) {
  return item.label?.trim() || item.name?.trim() || item.code;
}

function displayDate(value: string) {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function FieldError({ message }: { message?: string }) {
  return message ? <p className="mt-2 text-sm font-medium text-red-700">{message}</p> : null;
}

function SubmitButton({ mode }: { mode: "create" | "edit" }) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending} className="rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 disabled:cursor-wait disabled:bg-slate-400 focus:outline-none focus:ring-4 focus:ring-emerald-200">
      {pending ? (mode === "edit" ? "Guardando…" : "Creando…") : (mode === "edit" ? "Guardar cambios" : "Crear actividad")}
    </button>
  );
}

export function ActivityForm({ options, activePeriod, initialValues, today, mode = "create", activityId }: Props) {
  const action = mode === "edit" && activityId ? updateActivity.bind(null, activityId) : createActivity;
  const [state, formAction] = useActionState<ActivityFormState, FormData>(action, {
    revision: 0, values: initialValues, errors: {}, message: null,
  });

  return (
    <form action={formAction} className="grid gap-6 sm:grid-cols-2" noValidate>
      <Fields key={state.revision} state={state} options={options} activePeriod={activePeriod} today={today} mode={mode} />
    </form>
  );
}

function Fields({ state, options, activePeriod, today, mode }: {
  state: ActivityFormState;
  options: ActivityFormOptions;
  activePeriod: AcademicPeriod;
  today: string;
  mode: "create" | "edit";
}) {
  const [values, setValues] = useState(state.values);
  const calculatedEnd = useMemo(
    () => calculatePresetEnd(values.start_date, values.start_time, values.duration_mode as DurationMode),
    [values.duration_mode, values.start_date, values.start_time],
  );
  const set = (field: keyof ActivityFormValues, value: string) =>
    setValues((current) => ({ ...current, [field]: value }));
  const inputClass = (field: keyof ActivityFormValues) =>
    `mt-2 w-full rounded-xl border bg-white px-4 py-3 text-slate-900 outline-none transition focus:ring-4 ${state.errors[field] ? "border-red-400 focus:border-red-600 focus:ring-red-100" : "border-slate-300 focus:border-emerald-700 focus:ring-emerald-100"}`;
  const common = (field: keyof ActivityFormValues) => ({
    value: values[field],
    onChange: (event: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => set(field, event.target.value),
    "aria-invalid": Boolean(state.errors[field]),
    "aria-describedby": state.errors[field] ? `${field}-error` : undefined,
    className: inputClass(field),
  });
  const select = (id: keyof ActivityFormValues, title: string, empty: string, items: CatalogRow[]) => (
    <div>
      <label htmlFor={id} className="block text-sm font-semibold text-slate-700">{title}</label>
      <select id={id} name={id} required {...common(id)}>
        <option value="">{empty}</option>
        {items.map((item) => <option key={item.id} value={item.code}>{label(item)}</option>)}
      </select>
      <div id={`${id}-error`}><FieldError message={state.errors[id]} /></div>
    </div>
  );

  return (
    <>
      {state.message && (
        <div role="alert" className="sm:col-span-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800">
          <p className="font-semibold">Revisa los campos señalados.</p><p>{state.message}</p>
        </div>
      )}
      <div className="sm:col-span-2 rounded-2xl border border-emerald-200 bg-emerald-50 p-5">
        <p className="text-sm font-semibold text-emerald-700">Periodo académico activo</p>
        <p className="mt-1 text-lg font-bold text-emerald-950">{label(activePeriod)}</p>
        <FieldError message={state.errors.academic_period_id} />
      </div>
      <div className="sm:col-span-2">
        <label htmlFor="title" className="block text-sm font-semibold text-slate-700">Título</label>
        <input id="title" name="title" required maxLength={200} {...common("title")} />
        <FieldError message={state.errors.title} />
      </div>
      <div className="sm:col-span-2">
        <label htmlFor="description" className="block text-sm font-semibold text-slate-700">Descripción (opcional)</label>
        <textarea id="description" name="description" rows={4} maxLength={5000} {...common("description")} />
        <FieldError message={state.errors.description} />
      </div>
      <div>
        <label htmlFor="program_id" className="block text-sm font-semibold text-slate-700">Programa académico</label>
        <select id="program_id" name="program_id" required {...common("program_id")}>
          <option value="">Selecciona un programa</option>
          {options.programs.map((program) => <option key={program.id} value={program.id}>{program.name}</option>)}
        </select>
        <FieldError message={state.errors.program_id} />
      </div>
      {select("activity_type_code", "Tipo de actividad", "Selecciona un tipo", options.activityTypes)}
      {select("service_type_code", "Tipo de servicio", "Selecciona un servicio", options.serviceTypes)}
      {select("attention_category_code", "Categoría de atención", "Selecciona una categoría", options.attentionCategories)}
      {select("modality_code", "Modalidad", "Selecciona una modalidad", options.modalities)}
      {select("location_type_code", "Tipo de ubicación", "Selecciona un tipo de ubicación", options.locationTypes)}
      <div>
        <label htmlFor="location_detail" className="block text-sm font-semibold text-slate-700">Detalle de ubicación</label>
        <input id="location_detail" name="location_detail" required maxLength={500} placeholder="Aula, edificio o enlace" {...common("location_detail")} />
        <FieldError message={state.errors.location_detail} />
      </div>
      <div>
        <label htmlFor="start_date" className="block text-sm font-semibold text-slate-700">Fecha de inicio</label>
        <input id="start_date" name="start_date" type="date" required min={today} {...common("start_date")} />
        <FieldError message={state.errors.start_date} />
      </div>
      <div>
        <label htmlFor="start_time" className="block text-sm font-semibold text-slate-700">Hora de inicio</label>
        <input id="start_time" name="start_time" type="time" required step={60} lang="es-MX" {...common("start_time")} />
        <div className="mt-2 text-xs text-slate-500"><p>Usa formato de 24 horas.</p><p>Ejemplo: 14:30.</p></div>
        <FieldError message={state.errors.start_time} />
      </div>
      <div className="sm:col-span-2">
        <label htmlFor="duration_mode" className="block text-sm font-semibold text-slate-700">Duración</label>
        <select id="duration_mode" name="duration_mode" required {...common("duration_mode")}>
          <option value="one_hour">1 hora</option><option value="two_hours">2 horas</option><option value="custom">Personalizada</option>
        </select>
        <FieldError message={state.errors.duration_mode} />
      </div>
      {values.duration_mode === "custom" ? (
        <>
          <div>
            <label htmlFor="end_date" className="block text-sm font-semibold text-slate-700">Fecha de término</label>
            <input id="end_date" name="end_date" type="date" required min={values.start_date || today} {...common("end_date")} />
            <FieldError message={state.errors.end_date} />
          </div>
          <div>
            <label htmlFor="end_time" className="block text-sm font-semibold text-slate-700">Hora de término</label>
            <input id="end_time" name="end_time" type="time" required step={60} lang="es-MX" {...common("end_time")} />
            <div className="mt-2 text-xs text-slate-500"><p>Usa formato de 24 horas.</p><p>Ejemplo: 14:30.</p></div>
            <FieldError message={state.errors.end_time} />
          </div>
        </>
      ) : (
        <div className="sm:col-span-2 rounded-xl bg-slate-50 px-4 py-4 text-sm text-slate-700">
          <span className="font-semibold">Término calculado: </span>
          {calculatedEnd ? `${displayDate(calculatedEnd.endDate)} a las ${calculatedEnd.endTime}` : "Indica fecha y hora de inicio para calcularlo."}
        </div>
      )}
      <div className="sm:col-span-2 pt-2"><SubmitButton mode={mode} /></div>
    </>
  );
}
