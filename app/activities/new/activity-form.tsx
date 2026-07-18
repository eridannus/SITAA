"use client";

import { useActionState, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { useFormStatus } from "react-dom";
import { createActivity, resolveAcademicSemester, updateActivity } from "@/app/activities/actions";
import { calculatePresetEnd } from "@/lib/activities/date-time";
import { validateActivityForm } from "@/lib/activities/activity-form-validation";
import type { ActivityFormField, ActivityFormOptions, ActivityFormState, ActivityFormValues, ActivityScopeAccess, DurationMode } from "@/types/activities";
import type { CatalogRow } from "@/types/catalogs";

interface Props {
  options: ActivityFormOptions;
  access: ActivityScopeAccess;
  initialValues: ActivityFormValues;
  today?: string;
  mode?: "create" | "edit";
  activityId?: string;
  statusCode?: string;
  initialErrors?: ActivityFormState["errors"];
}
function label(item: CatalogRow) { return item.label?.trim() || item.name?.trim() || item.code; }
function displayDate(value: string) {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}
function FieldError({ field, message }: { field: ActivityFormField; message?: string }) {
  return message ? <p id={`${field}-error`} className="mt-2 text-sm font-medium text-[var(--sitaa-error-foreground)]">{message}</p> : null;
}
const ONLINE_MODALITY_CODE = "online";
const ONLINE_LOCATION_TYPE_CODE = "online_space";
const publicationFieldOrder: ActivityFormField[] = [
  "title", "description", "program_id", "activity_type_code", "service_type_code",
  "attention_category_code", "modality_code", "location_type_code", "location_detail",
  "start_date", "start_time", "duration_mode", "end_date", "end_time",
];
const scheduleFields: ActivityFormField[] = [
  "start_date", "start_time", "duration_mode", "end_date", "end_time",
];

function focusFirstInvalid(errors: ActivityFormState["errors"]) {
  const firstField = publicationFieldOrder.find((field) => Boolean(errors[field]));
  if (!firstField) return;
  requestAnimationFrame(() => {
    const element = document.getElementById(firstField);
    if (!element) return;
    element.scrollIntoView({ behavior: "smooth", block: "center" });
    element.focus({ preventScroll: true });
  });
}
function SubmitButtons({ mode, statusCode, confirmPublish, onCancelPublish }: { mode: "create" | "edit"; statusCode: string; confirmPublish: boolean; onCancelPublish: () => void }) {
  const { pending } = useFormStatus();
  const [pendingAction, setPendingAction] = useState<string | null>(null);
  const primaryClass = "sitaa-primary-action px-7";
  const secondaryClass = "sitaa-secondary-action px-7";
  const warningClass = "sitaa-primary-action px-7";
  const publishConfirmationMessage = "Una vez publicada, los datos base de la actividad quedar\u00e1n bloqueados para edici\u00f3n normal. Podr\u00e1s seguir gestionando participantes y asistencia.";

  if (confirmPublish) {
    return <div className="sitaa-alert sitaa-alert--warning grid gap-4 sm:col-span-2">
      <div>
        <p className="font-bold">Confirma la publicación</p>
        <p className="mt-2 leading-6">{publishConfirmationMessage}</p>
      </div>
      <div className="flex flex-col gap-3 sm:flex-row">
        <button type="submit" name="activity_intent" value="publish" disabled={pending} onClick={() => setPendingAction("publish")} className={warningClass}>{pending && pendingAction === "publish" ? "Publicando..." : "Confirmar publicación"}</button>
        <button type="button" disabled={pending} onClick={onCancelPublish} className={secondaryClass}>Cancelar</button>
      </div>
    </div>;
  }

  if (mode === "create") {
    return <div className="flex flex-col gap-3 sm:flex-row">
      <button type="submit" name="activity_intent" value="draft" disabled={pending} onClick={() => setPendingAction("draft")} className={secondaryClass}>{pending && pendingAction === "draft" ? "Guardando..." : "Guardar borrador"}</button>
      <button type="submit" name="activity_intent" value="validate_publish" disabled={pending} onClick={() => setPendingAction("validate_publish")} className={primaryClass}>{pending && pendingAction === "validate_publish" ? "Validando..." : "Publicar actividad"}</button>
    </div>;
  }
  return <div className="flex flex-col gap-3 sm:flex-row">
    <button type="submit" name="activity_intent" value="save" disabled={pending} onClick={() => setPendingAction("save")} className={primaryClass}>{pending && pendingAction === "save" ? "Guardando..." : "Guardar cambios"}</button>
    {statusCode === "draft" && <button type="submit" name="activity_intent" value="validate_publish" disabled={pending} onClick={() => setPendingAction("validate_publish")} className={secondaryClass}>{pending && pendingAction === "validate_publish" ? "Validando..." : "Publicar actividad"}</button>}
  </div>;
}

export function ActivityForm({ options, access, initialValues, mode = "create", activityId, statusCode = "draft", initialErrors = {} }: Props) {
  const action = mode === "edit" && activityId ? updateActivity.bind(null, activityId) : createActivity;
  const [state, formAction] = useActionState<ActivityFormState, FormData>(action, { revision: 0, values: initialValues, errors: initialErrors, message: null, confirmPublish: false });
  return <Fields key={state.revision} state={state} formAction={formAction} options={options} access={access} mode={mode} statusCode={statusCode} />;
}

function Fields({ state, formAction, options, access, mode, statusCode }: {
  state: ActivityFormState; options: ActivityFormOptions; access: ActivityScopeAccess;
  mode: "create" | "edit"; statusCode: string;
  formAction: (payload: FormData) => void;
}) {
  const [liveValues, setLiveValues] = useState(state.values);
  const [fieldErrors, setFieldErrors] = useState(state.errors);
  const [clientMessage, setClientMessage] = useState<string | null>(null);
  const [showPublishConfirmation, setShowPublishConfirmation] = useState(Boolean(state.confirmPublish));
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
  useEffect(() => {
    focusFirstInvalid(state.errors);
  }, [state.errors]);

  const publicationValues = (values: ActivityFormValues): ActivityFormValues => ({
    ...values,
    scope_type: "program",
    program_id: access.allowedPrograms.length === 1 ? access.allowedPrograms[0].id : values.program_id,
    location_type_code: values.modality_code === ONLINE_MODALITY_CODE
      ? ONLINE_LOCATION_TYPE_CODE
      : values.location_type_code === ONLINE_LOCATION_TYPE_CODE ? "" : values.location_type_code,
  });
  const revalidateChangedFields = (
    nextValues: ActivityFormValues,
    changedFields: ActivityFormField[],
  ) => {
    const validation = validateActivityForm(publicationValues(nextValues), {
      enforceFutureStartDate: true,
      requireOperationalFields: true,
    });
    setFieldErrors((current) => {
      const next = { ...current };
      const isScheduleChange = changedFields.some((field) => scheduleFields.includes(field));
      const fields = isScheduleChange ? scheduleFields : changedFields;
      const groupWasInvalid = fields.some((field) => Boolean(current[field]));
      for (const field of fields) {
        if (!current[field] && !(groupWasInvalid && validation.errors[field])) continue;
        if (validation.errors[field]) next[field] = validation.errors[field];
        else delete next[field];
      }
      return next;
    });
  };
  const set = (field: keyof ActivityFormValues, value: string) => {
    setShowPublishConfirmation(false);
    const next = { ...liveValues, [field]: value };
    setLiveValues(next);
    revalidateChangedFields(next, [field]);
  };
  const handleModalityChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
    const value = event.target.value;
    setShowPublishConfirmation(false);
    const next = {
      ...liveValues,
      modality_code: value,
      location_type_code: value === ONLINE_MODALITY_CODE ? ONLINE_LOCATION_TYPE_CODE : liveValues.location_type_code === ONLINE_LOCATION_TYPE_CODE ? "" : liveValues.location_type_code,
    };
    setLiveValues(next);
    revalidateChangedFields(next, ["modality_code", "location_type_code"]);
  };
  const isOnlineModality = liveValues.modality_code === ONLINE_MODALITY_CODE;
  const onlineLocationType = options.locationTypes.find((item) => item.code === ONLINE_LOCATION_TYPE_CODE);
  const onlineLocationLabel = onlineLocationType ? label(onlineLocationType) : "En línea";
  const nonOnlineLocationTypes = options.locationTypes.filter((item) => item.code !== ONLINE_LOCATION_TYPE_CODE);
  const inputClass = (field: keyof ActivityFormValues) => `sitaa-field mt-2 scroll-mt-24 ${fieldErrors[field] ? "sitaa-field-invalid" : ""}`;
  const common = (field: keyof ActivityFormValues, helperIds: string[] = []) => ({
    key: state.revision + ":" + field, defaultValue: state.values[field],
    onChange: (event: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => set(field, event.target.value),
    "aria-invalid": Boolean(fieldErrors[field]),
    "aria-describedby": [...helperIds, ...(fieldErrors[field] ? [`${field}-error`] : [])].join(" ") || undefined,
    className: inputClass(field),
  });
  const catalogSelect = (id: keyof ActivityFormValues, title: string, empty: string, items: CatalogRow[]) => <div>
    <label htmlFor={id} className="sitaa-form-label">{title}</label>
    <select id={id} name={id} required {...common(id)}><option value="">{empty}</option>{items.map((item) => <option key={item.id} value={item.code}>{label(item)}</option>)}</select>
    <FieldError field={id} message={fieldErrors[id]} />
  </div>;

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    const submitter = (event.nativeEvent as SubmitEvent).submitter as HTMLButtonElement | null;
    if (submitter?.value !== "validate_publish") return;
    const validation = validateActivityForm(publicationValues(liveValues), {
      enforceFutureStartDate: true,
      requireOperationalFields: true,
    });
    if (!Object.keys(validation.errors).length) return;
    event.preventDefault();
    setShowPublishConfirmation(false);
    setFieldErrors(validation.errors);
    setClientMessage("Corrige los campos indicados antes de confirmar la publicación.");
    focusFirstInvalid(validation.errors);
  };

  const hasFieldErrors = Object.keys(fieldErrors).length > 0;
  const summaryMessage = hasFieldErrors
    ? clientMessage ?? state.message
    : Object.keys(state.errors).length === 0 ? state.message : null;

  return <form action={formAction} onSubmit={handleSubmit} className="grid gap-6 sm:grid-cols-2" noValidate>
    {summaryMessage && <div role="alert" className="sitaa-alert sitaa-alert--error sm:col-span-2"><p className="font-semibold">Revisa los campos señalados.</p><p>{summaryMessage}</p></div>}
    <div className={`sitaa-alert sm:col-span-2 ${semesterInfo.tone === "warning" ? "sitaa-alert--warning" : "sitaa-alert--info"}`}><p className="text-sm font-semibold">{semesterInfo.text}</p><FieldError field="academic_period_id" message={fieldErrors.academic_period_id} /></div>
    <div className="sm:col-span-2"><label htmlFor="title" className="sitaa-form-label">Título</label><input id="title" name="title" required maxLength={200} {...common("title")} /><FieldError field="title" message={fieldErrors.title} /></div>
    <div className="sm:col-span-2"><label htmlFor="description" className="sitaa-form-label">Descripción (opcional)</label><textarea id="description" name="description" rows={4} maxLength={5000} {...common("description")} /><FieldError field="description" message={fieldErrors.description} /></div>

    {access.allowedPrograms.length === 1 ? <>
      <input type="hidden" name="scope_type" value="program" />
      <input type="hidden" name="program_id" value={access.allowedPrograms[0].id} />
      <div className="sitaa-read-only sm:col-span-2">
        <p className="text-sm font-semibold text-slate-500">Programa académico</p>
        <p className="mt-1 font-bold text-slate-900">{access.allowedPrograms[0].name}</p>
      </div>
    </> : <>
      <input type="hidden" name="scope_type" value="program" />
      <div className="sm:col-span-2">
        <label htmlFor="program_id" className="sitaa-form-label">Programa académico</label>
        <select id="program_id" name="program_id" required {...common("program_id")}>
          <option value="">Selecciona un programa</option>
          {access.allowedPrograms.map((program) => <option key={program.id} value={program.id}>{program.name}</option>)}
        </select>
        <FieldError field="program_id" message={fieldErrors.program_id} />
      </div>
    </>}

    {catalogSelect("activity_type_code", "Tipo de actividad", "Selecciona un tipo", options.activityTypes)}
    {catalogSelect("service_type_code", "Tipo de servicio", "Selecciona un servicio", options.serviceTypes)}
    {catalogSelect("attention_category_code", "Categoría de atención", "Selecciona una categoría", options.attentionCategories)}
    <div>
      <label htmlFor="modality_code" className="sitaa-form-label">Modalidad</label>
      <select id="modality_code" name="modality_code" required key={state.revision + ":modality_code"} defaultValue={state.values.modality_code} onChange={handleModalityChange} aria-invalid={Boolean(fieldErrors.modality_code)} aria-describedby={fieldErrors.modality_code ? "modality_code-error" : undefined} className={inputClass("modality_code")}>
        <option value="">Selecciona una modalidad</option>
        {options.modalities.map((item) => <option key={item.id} value={item.code}>{label(item)}</option>)}
      </select>
      <FieldError field="modality_code" message={fieldErrors.modality_code} />
    </div>
    {isOnlineModality ? <div>
      <input type="hidden" name="location_type_code" value={ONLINE_LOCATION_TYPE_CODE} />
      <p className="block text-sm font-semibold text-slate-700">Tipo de ubicación</p>
      <p className="sitaa-read-only mt-2 font-semibold">{onlineLocationLabel}</p>
      <FieldError field="location_type_code" message={fieldErrors.location_type_code} />
    </div> : <div>
      <label htmlFor="location_type_code" className="sitaa-form-label">Tipo de ubicación</label>
      <select id="location_type_code" name="location_type_code" required {...common("location_type_code")}>
        <option value="">Selecciona un tipo de ubicación</option>
        {nonOnlineLocationTypes.map((item) => <option key={item.id} value={item.code}>{label(item)}</option>)}
      </select>
      <FieldError field="location_type_code" message={fieldErrors.location_type_code} />
    </div>}
    <div><label htmlFor="location_detail" className="sitaa-form-label">Detalle de ubicación</label><input id="location_detail" name="location_detail" required maxLength={500} placeholder="Aula, edificio, enlace o datos de acceso" {...common("location_detail")} /><FieldError field="location_detail" message={fieldErrors.location_detail} /></div>
    <div><label htmlFor="start_date" className="sitaa-form-label">Fecha de inicio</label><input id="start_date" name="start_date" type="date" required {...common("start_date")} /><FieldError field="start_date" message={fieldErrors.start_date} /></div>
    <div><label htmlFor="start_time" className="sitaa-form-label">Hora de inicio</label><input id="start_time" name="start_time" type="time" required step={60} lang="es-MX" {...common("start_time", ["start_time-help"])} /><div id="start_time-help" className="sitaa-help-text mt-2"><p>Usa formato de 24 horas.</p><p>Ejemplo: 14:30.</p></div><FieldError field="start_time" message={fieldErrors.start_time} /></div>
    <div className="sm:col-span-2"><label htmlFor="duration_mode" className="sitaa-form-label">Duración</label><select id="duration_mode" name="duration_mode" required {...common("duration_mode")}><option value="one_hour">1 hora</option><option value="two_hours">2 horas</option><option value="custom">Personalizada</option></select><FieldError field="duration_mode" message={fieldErrors.duration_mode} /></div>
    {liveValues.duration_mode === "custom" ? <>
      <div><label htmlFor="end_date" className="sitaa-form-label">Fecha de término</label><input id="end_date" name="end_date" type="date" required min={liveValues.start_date || undefined} {...common("end_date")} /><FieldError field="end_date" message={fieldErrors.end_date} /></div>
      <div><label htmlFor="end_time" className="sitaa-form-label">Hora de término</label><input id="end_time" name="end_time" type="time" required step={60} lang="es-MX" {...common("end_time", ["end_time-help"])} /><div id="end_time-help" className="sitaa-help-text mt-2"><p>Usa formato de 24 horas.</p><p>Ejemplo: 14:30.</p></div><FieldError field="end_time" message={fieldErrors.end_time} /></div>
    </> : <div className="sitaa-read-only sm:col-span-2 text-sm"><span className="font-semibold">Término calculado: </span>{calculatedEnd ? `${displayDate(calculatedEnd.endDate)} a las ${calculatedEnd.endTime}` : "Indica fecha y hora de inicio para calcularlo."}</div>}
    <div className="sm:col-span-2 pt-2"><SubmitButtons mode={mode} statusCode={statusCode} confirmPublish={showPublishConfirmation} onCancelPublish={() => setShowPublishConfirmation(false)} /></div>
  </form>;
}
