"use server";

import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { getSiteOrigin } from "@/lib/auth/site-url";
import {
  oauthCookieOptions,
  REGISTRATION_INTENT_COOKIE,
} from "@/lib/auth/oauth-cookies";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  RegistrationField,
  RegistrationFormValues,
  RegistrationPersonType,
  RegistrationState,
} from "@/types/registration";

const digitsPattern = /^[0-9]+$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function text(formData: FormData, name: string) {
  const value = formData.get(name);
  return typeof value === "string" ? value.trim() : "";
}

function personType(value: string): RegistrationPersonType | "" {
  return value === "student" || value === "professor" ? value : "";
}

function registrationValuesFrom(formData: FormData): RegistrationFormValues {
  return {
    person_type: personType(text(formData, "person_type")),
    full_name: text(formData, "full_name").replace(/\s+/g, " "),
    institutional_id_value: text(formData, "institutional_id_value"),
    primary_program_id: text(formData, "primary_program_id"),
  };
}

function validationError(
  values: RegistrationFormValues,
  fieldErrors: RegistrationState["fieldErrors"],
  message = "Revisa los campos marcados para continuar.",
): RegistrationState {
  return { status: "error", message, fieldErrors, values };
}

function validateRegistration(values: RegistrationFormValues) {
  const errors: Partial<Record<RegistrationField, string>> = {};
  if (!values.person_type) errors.person_type = "Selecciona si eres alumno o profesor.";
  if (values.full_name.length < 2 || values.full_name.length > 200) {
    errors.full_name = "Escribe tu nombre completo (de 2 a 200 caracteres).";
  }
  if (!digitsPattern.test(values.institutional_id_value)) {
    errors.institutional_id_value = "Usa únicamente dígitos, sin espacios, letras ni signos.";
  } else if (values.institutional_id_value.length > 50) {
    errors.institutional_id_value = "El identificador no puede exceder 50 dígitos.";
  }
  if (!uuidPattern.test(values.primary_program_id)) {
    errors.primary_program_id = "Selecciona un programa académico.";
  }
  return errors;
}

function mapRegistrationError(message: string, code?: string) {
  const normalized = message.toLowerCase();
  if (code === "23505" || normalized.includes("sitaa_identifier_conflict")) {
    return {
      field: "institutional_id_value" as RegistrationField,
      message: "No fue posible usar ese identificador institucional. Verifica el dato capturado.",
    };
  }
  if (normalized.includes("program")) {
    return {
      field: "primary_program_id" as RegistrationField,
      message: "El programa seleccionado no está disponible.",
    };
  }
  if (normalized.includes("full_name")) {
    return { field: "full_name" as RegistrationField, message: "El nombre completo no es válido." };
  }
  if (normalized.includes("identifier")) {
    return {
      field: "institutional_id_value" as RegistrationField,
      message: "El identificador institucional no es válido.",
    };
  }
  return { message: "El registro no está disponible temporalmente. Intenta más tarde." };
}

async function createIntent(values: RegistrationFormValues) {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("create_registration_intent", {
    requested_person_type: values.person_type,
    requested_full_name: values.full_name,
    requested_institutional_id_value: values.institutional_id_value,
    requested_primary_program_id: values.primary_program_id,
  });
  return { supabase, token: typeof data === "string" ? data : null, error };
}

export async function startGoogleRegistration(
  _previous: RegistrationState,
  formData: FormData,
): Promise<RegistrationState> {
  const values = registrationValuesFrom(formData);
  const fieldErrors = validateRegistration(values);
  if (Object.keys(fieldErrors).length) return validationError(values, fieldErrors);

  let oauthUrl: string;
  try {
    const { supabase, token, error } = await createIntent(values);
    if (error || !token) {
      const mapped = mapRegistrationError(error?.message ?? "intent_unavailable", error?.code);
      return validationError(values, mapped.field ? { [mapped.field]: mapped.message } : {}, mapped.message);
    }

    const cookieStore = await cookies();
    cookieStore.set(REGISTRATION_INTENT_COOKIE, token, oauthCookieOptions());

    const requestHeaders = await headers();
    const origin = getSiteOrigin(
      requestHeaders.get("origin"),
      requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host"),
      requestHeaders.get("x-forwarded-proto"),
    );
    const { data, error: oauthError } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: new URL("/auth/callback", origin).toString() },
    });
    if (oauthError || !data.url) {
      cookieStore.delete(REGISTRATION_INTENT_COOKIE);
      return validationError(values, {}, "No fue posible iniciar el acceso con Google.");
    }
    oauthUrl = data.url;
  } catch {
    return validationError(values, {}, "El registro no está configurado temporalmente.");
  }
  redirect(oauthUrl);
}

export async function completeGoogleRegistration(
  _previous: RegistrationState,
  formData: FormData,
): Promise<RegistrationState> {
  const values = registrationValuesFrom(formData);
  const fieldErrors = validateRegistration(values);
  if (Object.keys(fieldErrors).length) return validationError(values, fieldErrors);

  try {
    const { supabase, token, error } = await createIntent(values);
    if (error || !token) {
      const mapped = mapRegistrationError(error?.message ?? "intent_unavailable", error?.code);
      return validationError(values, mapped.field ? { [mapped.field]: mapped.message } : {}, mapped.message);
    }
    const { error: completionError } = await supabase.rpc("complete_own_google_registration", {
      raw_intent_token: token,
    });
    if (completionError) {
      const mapped = mapRegistrationError(completionError.message, completionError.code);
      return validationError(values, mapped.field ? { [mapped.field]: mapped.message } : {}, mapped.message);
    }
    (await cookies()).delete(REGISTRATION_INTENT_COOKIE);
  } catch {
    return validationError(values, {}, "No fue posible completar el registro. Intenta nuevamente.");
  }
  redirect("/dashboard?registration=completed");
}
