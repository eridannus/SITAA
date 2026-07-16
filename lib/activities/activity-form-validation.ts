import {
  calculatePresetEnd,
  getMexicoCityCurrentTime,
  getMexicoCityToday,
  isValidDate,
  isValidTime,
} from "@/lib/activities/date-time";
import type {
  ActivityFormState,
  ActivityFormValues,
  DurationMode,
} from "@/types/activities";

const durationModes = new Set<DurationMode>(["one_hour", "two_hours", "custom"]);

export const PUBLICATION_SCHEDULE_MESSAGE =
  "La fecha y hora de inicio deben ser posteriores a la hora actual de Ciudad de México.";

interface ValidationOptions {
  enforceFutureStartDate: boolean;
  requireOperationalFields: boolean;
}

interface ScheduleValidationOptions {
  enforceFutureStartDate?: boolean;
  today?: string;
  currentTime?: string;
}

export function getPublicationScheduleFieldErrors(
  values: Pick<ActivityFormValues, "start_date" | "start_time">,
  options: ScheduleValidationOptions = {},
): ActivityFormState["errors"] {
  const errors: ActivityFormState["errors"] = {};
  const dateIsValid = isValidDate(values.start_date);
  const timeIsValid = isValidTime(values.start_time);
  const enforceFutureStartDate = options.enforceFutureStartDate ?? true;
  const today = options.today ?? getMexicoCityToday();
  const currentTime = options.currentTime ?? getMexicoCityCurrentTime();

  if (!dateIsValid) {
    errors.start_date = "Indica una fecha de inicio válida.";
  } else if (enforceFutureStartDate && values.start_date < today) {
    errors.start_date = "La fecha de inicio no puede ser anterior a hoy.";
  }

  if (!timeIsValid) {
    errors.start_time = "Indica una hora válida en formato de 24 horas.";
  } else if (
    enforceFutureStartDate &&
    dateIsValid &&
    values.start_date === today &&
    values.start_time <= currentTime
  ) {
    errors.start_time = "La hora de inicio debe ser posterior a la hora actual.";
  }

  return errors;
}

export function getPublicationScheduleRejectionErrors(
  values: Pick<ActivityFormValues, "start_date" | "start_time">,
): ActivityFormState["errors"] {
  const errors = getPublicationScheduleFieldErrors(values);
  if (Object.keys(errors).length) return errors;

  return {
    start_date: PUBLICATION_SCHEDULE_MESSAGE,
    start_time: PUBLICATION_SCHEDULE_MESSAGE,
  };
}

export function validateActivityForm(
  values: ActivityFormValues,
  { enforceFutureStartDate, requireOperationalFields }: ValidationOptions,
) {
  const errors: ActivityFormState["errors"] = {};
  if (!values.title) errors.title = "Escribe el título de la actividad.";
  else if (values.title.length > 200) errors.title = "El título no puede exceder 200 caracteres.";
  if (values.description.length > 5000) errors.description = "La descripción no puede exceder 5000 caracteres.";
  if (values.scope_type !== "program" && values.scope_type !== "division") errors.scope_type = "Selecciona el alcance de la actividad.";
  if (values.scope_type === "program" && !values.program_id) errors.program_id = "Selecciona un programa académico.";

  if (requireOperationalFields) {
    if (!values.activity_type_code) errors.activity_type_code = "Selecciona un tipo de actividad.";
    if (!values.service_type_code) errors.service_type_code = "Selecciona un tipo de servicio.";
    if (!values.attention_category_code) errors.attention_category_code = "Selecciona una categoría de atención.";
    if (!values.modality_code) errors.modality_code = "Selecciona una modalidad.";
    if (!values.location_type_code) errors.location_type_code = "Selecciona un tipo de ubicación.";
    if (!values.location_detail) errors.location_detail = "Indica el lugar, aula, enlace o detalle de acceso de la actividad.";
    Object.assign(
      errors,
      getPublicationScheduleFieldErrors(values, { enforceFutureStartDate }),
    );
    if (!durationModes.has(values.duration_mode as DurationMode)) errors.duration_mode = "Selecciona una duración.";
  }
  if (values.location_detail.length > 500) errors.location_detail = "El detalle no puede exceder 500 caracteres.";

  let endDate = values.end_date;
  let endTime = values.end_time;
  const durationMode = values.duration_mode as DurationMode;
  if (!requireOperationalFields && !durationModes.has(durationMode)) {
    return { errors, endDate: "", endTime: "", durationMode: null };
  }
  if (durationMode === "custom") {
    if (requireOperationalFields && !isValidDate(endDate)) errors.end_date = "Indica una fecha de término válida.";
    if (requireOperationalFields && !isValidTime(endTime)) errors.end_time = "Indica una hora válida en formato de 24 horas.";
    if (isValidDate(values.start_date) && isValidDate(endDate)) {
      if (endDate < values.start_date) errors.end_date = "La fecha de término no puede ser anterior al inicio.";
      else if (
        endDate === values.start_date &&
        isValidTime(values.start_time) &&
        isValidTime(endTime) &&
        endTime <= values.start_time
      ) errors.end_time = "La hora de término debe ser posterior a la hora de inicio.";
    }
  } else if (durationMode === "one_hour" || durationMode === "two_hours") {
    const calculated = calculatePresetEnd(values.start_date, values.start_time, durationMode);
    if (calculated) {
      endDate = calculated.endDate;
      endTime = calculated.endTime;
    }
  }

  return { errors, endDate, endTime, durationMode };
}
