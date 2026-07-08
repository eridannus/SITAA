"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  calculatePresetEnd,
  getMexicoCityToday,
  isValidDate,
  isValidTime,
  toMexicoCityTimestamp,
} from "@/lib/activities/date-time";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  ActivityFormField,
  ActivityFormState,
  ActivityFormValues,
  DurationMode,
} from "@/types/activities";

const durationModes = new Set<DurationMode>(["one_hour", "two_hours", "custom"]);

function getText(formData: FormData, field: keyof ActivityFormValues) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim() : "";
}

function getValues(formData: FormData): ActivityFormValues {
  return {
    title: getText(formData, "title").replace(/\s+/g, " "),
    description: getText(formData, "description"),
    program_id: getText(formData, "program_id"),
    activity_type_code: getText(formData, "activity_type_code"),
    service_type_code: getText(formData, "service_type_code"),
    attention_category_code: getText(formData, "attention_category_code"),
    modality_code: getText(formData, "modality_code"),
    location_type_code: getText(formData, "location_type_code"),
    location_detail: getText(formData, "location_detail"),
    start_date: getText(formData, "start_date"),
    start_time: getText(formData, "start_time"),
    duration_mode: getText(formData, "duration_mode"),
    end_date: getText(formData, "end_date"),
    end_time: getText(formData, "end_time"),
  };
}

function invalidState(
  previousState: ActivityFormState,
  values: ActivityFormValues,
  errors: ActivityFormState["errors"],
  message = "Revisa los campos marcados antes de continuar.",
): ActivityFormState {
  return {
    revision: previousState.revision + 1,
    values,
    errors,
    message,
  };
}

function validateValues(values: ActivityFormValues) {
  const errors: Partial<Record<ActivityFormField, string>> = {};

  if (!values.title) errors.title = "Escribe el título de la actividad.";
  else if (values.title.length > 200) errors.title = "El título no puede exceder 200 caracteres.";
  if (values.description.length > 5000) {
    errors.description = "La descripción no puede exceder 5000 caracteres.";
  }
  if (!values.program_id) errors.program_id = "Selecciona un programa académico.";
  if (!values.activity_type_code) {
    errors.activity_type_code = "Selecciona un tipo de actividad.";
  }
  if (!values.service_type_code) errors.service_type_code = "Selecciona un tipo de servicio.";
  if (!values.attention_category_code) {
    errors.attention_category_code = "Selecciona una categoría de atención.";
  }
  if (!values.modality_code) errors.modality_code = "Selecciona una modalidad.";
  if (!values.location_type_code) {
    errors.location_type_code = "Selecciona un tipo de ubicación.";
  }
  if (!values.location_detail) {
    errors.location_detail = "Indica el lugar, aula o enlace de la actividad.";
  } else if (values.location_detail.length > 500) {
    errors.location_detail = "El detalle no puede exceder 500 caracteres.";
  }
  if (!isValidDate(values.start_date)) errors.start_date = "Indica una fecha de inicio válida.";
  if (!isValidTime(values.start_time)) {
    errors.start_time = "Indica una hora válida en formato de 24 horas.";
  }
  if (!durationModes.has(values.duration_mode as DurationMode)) {
    errors.duration_mode = "Selecciona una duración.";
  }

  if (isValidDate(values.start_date) && values.start_date < getMexicoCityToday()) {
    errors.start_date = "La fecha de inicio no puede ser anterior a hoy.";
  }

  let endDate = values.end_date;
  let endTime = values.end_time;
  const durationMode = values.duration_mode as DurationMode;

  if (durationMode === "custom") {
    if (!isValidDate(endDate)) errors.end_date = "Indica una fecha de término válida.";
    if (!isValidTime(endTime)) {
      errors.end_time = "Indica una hora válida en formato de 24 horas.";
    }

    if (isValidDate(values.start_date) && isValidDate(endDate)) {
      if (endDate < values.start_date) {
        errors.end_date = "La fecha de término no puede ser anterior al inicio.";
      } else if (
        endDate === values.start_date &&
        isValidTime(values.start_time) &&
        isValidTime(endTime) &&
        endTime <= values.start_time
      ) {
        errors.end_time = "La hora de término debe ser posterior a la hora de inicio.";
      }
    }
  } else if (durationMode === "one_hour" || durationMode === "two_hours") {
    const calculatedEnd = calculatePresetEnd(values.start_date, values.start_time, durationMode);

    if (calculatedEnd) {
      endDate = calculatedEnd.endDate;
      endTime = calculatedEnd.endTime;
    }
  }

  return { errors, endDate, endTime, durationMode };
}

async function saveActivity(
  activityId: string | null,
  previousState: ActivityFormState,
  formData: FormData,
): Promise<ActivityFormState> {
  const values = getValues(formData);
  const { errors, endDate, endTime, durationMode } = validateValues(values);

  if (Object.keys(errors).length > 0) {
    return invalidState(previousState, values, errors);
  }

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login?error=sesion-requerida");

  const [{ data: profile, error: profileError }, { data: periods, error: periodError }] =
    await Promise.all([
      supabase.from("profiles").select("id").eq("id", user.id).maybeSingle(),
      supabase.from("academic_periods").select("*").eq("is_active", true).limit(2),
    ]);

  if (profileError || !profile) {
    return invalidState(
      previousState,
      values,
      {},
      "Tu cuenta necesita un perfil institucional activo.",
    );
  }

  if (periodError || !periods || periods.length !== 1) {
    return invalidState(
      previousState,
      values,
      { academic_period_id: "No hay un periodo académico activo y único." },
      "No es posible guardar actividades hasta configurar un periodo académico activo.",
    );
  }

  async function isAvailable(table: string, column: string, value: string) {
    const { data, error } = await supabase
      .from(table)
      .select("*")
      .eq(column, value)
      .maybeSingle();
    return !error && Boolean(data) && data?.is_active !== false;
  }

  const catalogChecks: Array<[ActivityFormField, Promise<boolean>]> = [
    ["program_id", isAvailable("academic_programs", "id", values.program_id)],
    ["activity_type_code", isAvailable("activity_types", "code", values.activity_type_code)],
    ["service_type_code", isAvailable("service_types", "code", values.service_type_code)],
    [
      "attention_category_code",
      isAvailable("attention_categories", "code", values.attention_category_code),
    ],
    ["modality_code", isAvailable("activity_modalities", "code", values.modality_code)],
    ["location_type_code", isAvailable("location_types", "code", values.location_type_code)],
  ];
  const catalogResults = await Promise.all(catalogChecks.map(([, check]) => check));

  catalogResults.forEach((isValid, index) => {
    if (!isValid) {
      errors[catalogChecks[index][0]] = "La opción seleccionada ya no está disponible.";
    }
  });

  if (Object.keys(errors).length > 0) {
    return invalidState(previousState, values, errors);
  }

  const payload = {
    title: values.title,
    description: values.description || null,
    academic_period_id: periods[0].id,
    program_id: values.program_id,
    activity_type_code: values.activity_type_code,
    service_type_code: values.service_type_code,
    attention_category_code: values.attention_category_code,
    modality_code: values.modality_code,
    location_type_code: values.location_type_code,
    location_detail: values.location_detail,
    start_date: values.start_date,
    start_time: values.start_time,
    end_date: endDate,
    end_time: endTime,
    duration_mode: durationMode,
    starts_at: toMexicoCityTimestamp(values.start_date, values.start_time),
    ends_at: toMexicoCityTimestamp(endDate, endTime),
  };

  if (activityId) {
    const { data: updated, error } = await supabase
      .from("activities")
      .update(payload)
      .eq("id", activityId)
      .select("id")
      .maybeSingle();

    if (error || !updated) {
      return invalidState(
        previousState,
        values,
        {},
        "No fue posible actualizar la actividad. Verifica tus permisos e intenta nuevamente.",
      );
    }

    revalidatePath("/activities");
    revalidatePath(`/activities/${activityId}`);
    redirect(`/activities/${activityId}?updated=1`);
  }

  const { error } = await supabase.from("activities").insert({
    ...payload,
    responsible_profile_id: profile.id,
    created_by: user.id,
    status_code: "scheduled",
  });

  if (error) {
    return invalidState(
      previousState,
      values,
      {},
      "No fue posible crear la actividad. Verifica tus permisos e intenta nuevamente.",
    );
  }

  revalidatePath("/activities");
  redirect("/activities?created=1");
}

export async function createActivity(
  previousState: ActivityFormState,
  formData: FormData,
): Promise<ActivityFormState> {
  return saveActivity(null, previousState, formData);
}

export async function updateActivity(
  activityId: string,
  previousState: ActivityFormState,
  formData: FormData,
): Promise<ActivityFormState> {
  return saveActivity(activityId, previousState, formData);
}

export async function deleteActivity(activityId: string, formData: FormData) {
  const confirmation = formData.get("confirmation");

  if (confirmation !== "confirmed") {
    redirect(`/activities/${activityId}?error=delete`);
  }

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login?error=sesion-requerida");

  const { data: deleted, error } = await supabase
    .from("activities")
    .delete()
    .eq("id", activityId)
    .select("id")
    .maybeSingle();

  if (error || !deleted) {
    redirect(`/activities/${activityId}?error=delete`);
  }

  revalidatePath("/activities");
  redirect("/activities?deleted=1");
}