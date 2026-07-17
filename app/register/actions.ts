"use server";

import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { getSiteOrigin } from "@/lib/auth/site-url";
import {
  clearCallbackCookie,
  oauthCallbackCookieOptions,
  REGISTRATION_TYPE_COOKIE,
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

function normalizePersonType(value: string): RegistrationPersonType | "" {
  return value === "student" || value === "professor" ? value : "";
}

function registrationValuesFrom(formData: FormData): RegistrationFormValues {
  return {
    person_type: normalizePersonType(text(formData, "person_type")),
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
  if (!values.person_type) errors.person_type = "El tipo de registro no es válido.";
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
      message: "Ese identificador institucional ya está registrado en SITAA.",
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
  return { message: "No fue posible completar el registro. Intenta nuevamente." };
}

export async function startGoogleRegistration(formData: FormData) {
  const registrationType = normalizePersonType(text(formData, "registration_type"));
  if (!registrationType) redirect("/register?error=tipo-invalido");

  let oauthUrl: string | null = null;
  let failurePath: string | null = null;
  try {
    const supabase = await createSupabaseServerClient();
    const cookieStore = await cookies();
    cookieStore.set(
      REGISTRATION_TYPE_COOKIE,
      registrationType,
      oauthCallbackCookieOptions(),
    );

    const requestHeaders = await headers();
    const origin = getSiteOrigin(
      requestHeaders.get("origin"),
      requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host"),
      requestHeaders.get("x-forwarded-proto"),
    );
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: new URL("/auth/callback", origin).toString() },
    });
    if (error || !data.url) {
      clearCallbackCookie(cookieStore, REGISTRATION_TYPE_COOKIE);
      failurePath = `/register/${registrationType}?error=google`;
    } else {
      oauthUrl = data.url;
    }
  } catch {
    failurePath = `/register/${registrationType}?error=configuracion`;
  }
  if (failurePath) redirect(failurePath);
  if (!oauthUrl) redirect(`/register/${registrationType}?error=google`);
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
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.rpc("complete_own_google_registration", {
      requested_person_type: values.person_type,
      requested_full_name: values.full_name,
      requested_institutional_id_value: values.institutional_id_value,
      requested_primary_program_id: values.primary_program_id,
    });
    if (error) {
      const mapped = mapRegistrationError(error.message, error.code);
      return validationError(
        values,
        mapped.field ? { [mapped.field]: mapped.message } : {},
        mapped.message,
      );
    }
  } catch {
    return validationError(values, {}, "No fue posible completar el registro. Intenta nuevamente.");
  }
  redirect("/dashboard?registration=completed");
}
