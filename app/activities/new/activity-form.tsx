"use client";

import { useActionState, useMemo, useState } from "react";
import { useFormStatus } from "react-dom";
import { createActivity } from "@/app/activities/actions";
import { calculatePresetEnd } from "@/lib/activities/date-time";
import type {
  ActivityFormOptions,
  ActivityFormState,
  ActivityFormValues,
  DurationMode,
} from "@/types/activities";
import type { AcademicPeriod, CatalogRow } from "@/types/catalogs";

interface ActivityFormProps {
  options: ActivityFormOptions;
  activePeriod: AcademicPeriod;
  initialProgramId: string;
  today: string;
}

function getLabel(item: CatalogRow) {
  return item.label?.trim() || item.name?.trim() || item.code;
}

function FieldError({ message }: { message?: string }) {
  if (!message) return null;
  return <p className="mt-2 text-sm font-medium text-red-700">{message}</p>;
}

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 disabled:cursor-wait disabled:bg-slate-400 focus:outline-none focus:ring-4 focus:ring-emerald-200"
    >
      {pending ? "Creando…" : "Crear actividad"}
    </button>
  );
}

export function ActivityForm({
  options,
  activePeriod,
  initialProgramId,
  today,
}: ActivityFormProps) {
  const initialValues: ActivityFormValues = {
    title: "",
    description: "",
    program_id: initialProgramId,
    activity_type_code: "",
    service_type_code: "",
    attention_category_code: "",
    modality_code: "",
    location_type_code: "",
    location_detail: "",
    start_date: "",
    start_time: "",
    duration_mode: "one_hour",
    end_date: "",
    end_time: "",
  };
  const [state, formAction] = useActionState<ActivityFormState, FormData>(createActivity, {
    values: initialValues,
    errors: {},
    message: null,
  });
  const [values, setValues] = useState(initialValues);
  const calculatedEnd = useMemo(
    () =>
      calculatePresetEnd(
        values.start_date,
        values.start_time,
        values.duration_mode as DurationMode,
      ),
    [values.duration_mode, values.start_date, values.start_time],
  );

  function setValue(field: keyof ActivityFormValues, value: string) {
    setValues((current) => ({ ...current, [field]: value }));
  }

  function inputClass(field: keyof ActivityFormValues) {
    return [
      "mt-2 w-full rounded-xl border bg-white px-4 py-3 text-slate-900 outline-none transition focus:ring-4",
      state.errors[field]
        ? "border-red-400 focus:border-red-600 focus:ring-red-100"
        : "border-slate-300 focus:border-emerald-700 focus:ring-emerald-100",
    ].join(" ");
  }

  return (
    <form action={formAction} className="grid gap-6 sm:grid-cols-2" noValidate>
      {state.message && (
        <div role="alert" className="sm:col-span-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800">
          <p className="font-semibold">No se pudo crear la actividad.</p>
          <p>{state.message}</p>
        </div>
      )}

      <div className="sm:col-span-2 rounded-2xl border border-emerald-200 bg-emerald-50 p-5">
        <p className="text-sm font-semibold text-emerald-700">Periodo académico activo</p>
        <p className="mt-1 text-lg font-bold text-emerald-950">{getLabel(activePeriod)}</p>
        <FieldError message={state.errors.academic_period_id} />
      </div>

      <div className="sm:col-span-2">
        <label htmlFor="title" className="block text-sm font-semibold text-slate-700">Título</label>
        <input id="title" name="title" required value={values.title} onChange={(event) => setValue("title", event.target.value)} maxLength={200} aria-invalid={Boolean(state.errors.title)} className={inputClass("title")} />
        <FieldError message={state.errors.title} />
      </div>

      <div className="sm:col-span-2">
        <label htmlFor="description" className="block text-sm font-semibold text-slate-700">Descripción</label>
        <textarea id="description" name="description" rows={4} value={values.description} onChange={(event) => setValue("description", event.target.value)} maxLength={5000} aria-invalid={Boolean(state.errors.description)} className={inputClass("description")} />
        <FieldError message={state.errors.description} />
      </div>

      <div>
        <label htmlFor="program_id" className="block text-sm font-semibold text-slate-700">Programa académico</label>
        <select id="program_id" name="program_id" required value={values.program_id} onChange={(event) => setValue("program_id", event.target.value)} aria-invalid={Boolean(state.errors.program_id)} className={inputClass("program_id")}>
          <option value="">Selecciona un programa</option>
          {options.programs.map((program) => (
            <option key={program.id} value={program.id}>{program.name}</option>
          ))}
        </select>
        <FieldError message={state.errors.program_id} />
      </div>

      <div>
        <label htmlFor="activity_type_code" className="block text-sm font-semibold text-slate-700">Tipo de actividad</label>
        <select id="activity_type_code" name="activity_type_code" required value={values.activity_type_code} onChange={(event) => setValue("activity_type_code", event.target.value)} aria-invalid={Boolean(state.errors.activity_type_code)} className={inputClass("activity_type_code")}>
          <option value="">Selecciona un tipo</option>
          {options.activityTypes.map((item) => (
            <option key={item.id} value={item.code}>{getLabel(item)}</option>
          ))}
        </select>
        <FieldError message={state.errors.activity_type_code} />
      </div>

      <div>
        <label htmlFor="service_type_code" className="block text-sm font-semibold text-slate-700">Tipo de servicio</label>
        <select id="service_type_code" name="service_type_code" required value={values.service_type_code} onChange={(event) => setValue("service_type_code", event.target.value)} aria-invalid={Boolean(state.errors.service_type_code)} className={inputClass("service_type_code")}>
          <option value="">Selecciona un servicio</option>
          {options.serviceTypes.map((item) => (
            <option key={item.id} value={item.code}>{getLabel(item)}</option>
          ))}
        </select>
        <FieldError message={state.errors.service_type_code} />
      </div>

      <div>
        <label htmlFor="attention_category_code" className="block text-sm font-semibold text-slate-700">Categoría de atención</label>
        <select id="attention_category_code" name="attention_category_code" value={values.attention_category_code} onChange={(event) => setValue("attention_category_code", event.target.value)} aria-invalid={Boolean(state.errors.attention_category_code)} className={inputClass("attention_category_code")}>
          <option value="">Sin categoría</option>
          {options.attentionCategories.map((item) => (
            <option key={item.id} value={item.code}>{getLabel(item)}</option>
          ))}
        </select>
        <FieldError message={state.errors.attention_category_code} />
      </div>

      <div>
        <label htmlFor="modality_code" className="block text-sm font-semibold text-slate-700">Modalidad</label>
        <select id="modality_code" name="modality_code" required value={values.modality_code} onChange={(event) => setValue("modality_code", event.target.value)} aria-invalid={Boolean(state.errors.modality_code)} className={inputClass("modality_code")}>
          <option value="">Selecciona una modalidad</option>
          {options.modalities.map((item) => (
            <option key={item.id} value={item.code}>{getLabel(item)}</option>
          ))}
        </select>
        <FieldError message={state.errors.modality_code} />
      </div>

      <div>
        <label htmlFor="location_type_code" className="block text-sm font-semibold text-slate-700">Tipo de ubicación</label>
        <select id="location_type_code" name="location_type_code" value={values.location_type_code} onChange={(event) => setValue("location_type_code", event.target.value)} aria-invalid={Boolean(state.errors.location_type_code)} className={inputClass("location_type_code")}>
          <option value="">Sin tipo de ubicación</option>
          {options.locationTypes.map((item) => (
            <option key={item.id} value={item.code}>{getLabel(item)}</option>
          ))}
        </select>
        <FieldError message={state.errors.location_type_code} />
      </div>

      <div>
        <label htmlFor="location_detail" className="block text-sm font-semibold text-slate-700">Detalle de ubicación</label>
        <input id="location_detail" name="location_detail" value={values.location_detail} onChange={(event) => setValue("location_detail", event.target.value)} maxLength={500} placeholder="Aula, edificio o enlace" aria-invalid={Boolean(state.errors.location_detail)} className={inputClass("location_detail")} />
        <FieldError message={state.errors.location_detail} />
      </div>

      <div>
        <label htmlFor="start_date" className="block text-sm font-semibold text-slate-700">Fecha de inicio</label>
        <input id="start_date" name="start_date" type="date" required min={today} value={values.start_date} onChange={(event) => setValue("start_date", event.target.value)} aria-invalid={Boolean(state.errors.start_date)} className={inputClass("start_date")} />
        <FieldError message={state.errors.start_date} />
      </div>

      <div>
        <label htmlFor="start_time" className="block text-sm font-semibold text-slate-700">Hora de inicio</label>
        <input id="start_time" name="start_time" type="time" required step={60} lang="es-MX" value={values.start_time} onChange={(event) => setValue("start_time", event.target.value)} aria-invalid={Boolean(state.errors.start_time)} className={inputClass("start_time")} />
        <p className="mt-2 text-xs text-slate-500">Formato de 24 horas, por ejemplo 09:00 o 14:30.</p>
        <FieldError message={state.errors.start_time} />
      </div>

      <div className="sm:col-span-2">
        <label htmlFor="duration_mode" className="block text-sm font-semibold text-slate-700">Duración</label>
        <select id="duration_mode" name="duration_mode" required value={values.duration_mode} onChange={(event) => setValue("duration_mode", event.target.value)} aria-invalid={Boolean(state.errors.duration_mode)} className={inputClass("duration_mode")}>
          <option value="one_hour">1 hora</option>
          <option value="two_hours">2 horas</option>
          <option value="custom">Personalizada</option>
        </select>
        <FieldError message={state.errors.duration_mode} />
      </div>

      {values.duration_mode === "custom" ? (
        <>
          <div>
            <label htmlFor="end_date" className="block text-sm font-semibold text-slate-700">Fecha de término</label>
            <input id="end_date" name="end_date" type="date" required min={values.start_date || today} value={values.end_date} onChange={(event) => setValue("end_date", event.target.value)} aria-invalid={Boolean(state.errors.end_date)} className={inputClass("end_date")} />
            <FieldError message={state.errors.end_date} />
          </div>
          <div>
            <label htmlFor="end_time" className="block text-sm font-semibold text-slate-700">Hora de término</label>
            <input id="end_time" name="end_time" type="time" required step={60} lang="es-MX" value={values.end_time} onChange={(event) => setValue("end_time", event.target.value)} aria-invalid={Boolean(state.errors.end_time)} className={inputClass("end_time")} />
            <p className="mt-2 text-xs text-slate-500">Formato de 24 horas, por ejemplo 09:00 o 14:30.</p>
            <FieldError message={state.errors.end_time} />
          </div>
        </>
      ) : (
        <div className="sm:col-span-2 rounded-xl bg-slate-50 px-4 py-4 text-sm text-slate-700">
          <span className="font-semibold">Término calculado: </span>
          {calculatedEnd
            ? `${calculatedEnd.endDate} a las ${calculatedEnd.endTime}`
            : "Indica fecha y hora de inicio para calcularlo."}
        </div>
      )}

      <div className="sm:col-span-2 pt-2">
        <SubmitButton />
      </div>
    </form>
  );
}