"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getSiteOrigin } from "@/lib/auth/site-url";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  RegistrationField,
  RegistrationFormValues,
  RegistrationPersonType,
  RegistrationState,
} from "@/types/registration";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const digitsPattern = /^[0-9]+$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function text(formData: FormData, name: string) {
  const value = formData.get(name);
  return typeof value === "string" ? value.trim() : "";
}

function valuesFrom(formData: FormData): RegistrationFormValues {
  return {
    full_name: text(formData, "full_name").replace(/\s+/g, " "),
    email: text(formData, "email").toLowerCase(),
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

function validate(
  values: RegistrationFormValues,
  password: string,
  passwordConfirmation: string,
) {
  const errors: Partial<Record<RegistrationField, string>> = {};

  if (values.full_name.length < 2 || values.full_name.length > 200) {
    errors.full_name = "Escribe tu nombre completo (máximo 200 caracteres).";
  }
  if (!emailPattern.test(values.email) || values.email.length > 254) {
    errors.email = "Escribe un correo electrónico válido.";
  }
  if (!digitsPattern.test(values.institutional_id_value) || values.institutional_id_value.length > 50) {
    errors.institutional_id_value = "Usa únicamente dígitos, sin espacios, letras ni signos.";
  }
  if (!uuidPattern.test(values.primary_program_id)) {
    errors.primary_program_id = "Selecciona un programa académico.";
  }
  if (password.length < 8) {
    errors.password = "La contraseña debe tener al menos 8 caracteres.";
  }
  if (password !== passwordConfirmation) {
    errors.password_confirmation = "Las contraseñas no coinciden.";
  }

  return errors;
}

function mapSignUpError(message: string, code?: string): { field?: RegistrationField; message: string } {
  const normalized = message.toLowerCase();

  if (normalized.includes("password") || normalized.includes("contraseña")) {
    return { field: "password", message: "La contraseña no cumple los requisitos de seguridad." };
  }
  if (normalized.includes("email") && (normalized.includes("invalid") || normalized.includes("inválid"))) {
    return { field: "email", message: "El correo electrónico no es válido." };
  }
  if (normalized.includes("already") || normalized.includes("registered") || normalized.includes("exists")) {
    return {
      field: "email",
      message: "No fue posible registrar ese correo. Si ya tienes una cuenta, inicia sesión.",
    };
  }
  if (
    code === "23505" ||
    normalized.includes("sitaa_identifier_conflict") ||
    normalized.includes("institutional identifier")
  ) {
    return {
      field: "institutional_id_value",
      message: "No fue posible usar ese identificador institucional. Verifica el dato capturado.",
    };
  }
  if (normalized.includes("program") || normalized.includes("programa")) {
    return { field: "primary_program_id", message: "El programa seleccionado no está disponible." };
  }

  return { message: "El registro no está disponible temporalmente. Intenta más tarde." };
}

export async function registerInstitutionalAccount(
  personType: RegistrationPersonType,
  _previous: RegistrationState,
  formData: FormData,
): Promise<RegistrationState> {
  if (personType !== "student" && personType !== "professor") {
    return validationError(valuesFrom(formData), {}, "El tipo de registro no es válido.");
  }

  const values = valuesFrom(formData);
  const password = formData.get("password");
  const passwordConfirmation = formData.get("password_confirmation");
  const safePassword = typeof password === "string" ? password : "";
  const safePasswordConfirmation =
    typeof passwordConfirmation === "string" ? passwordConfirmation : "";
  const fieldErrors = validate(values, safePassword, safePasswordConfirmation);

  if (Object.keys(fieldErrors).length > 0) {
    return validationError(values, fieldErrors);
  }

  let supabase;
  try {
    supabase = await createSupabaseServerClient();
  } catch {
    return validationError(values, {}, "El registro no está configurado temporalmente.");
  }

  const { data: program, error: programError } = await supabase
    .from("academic_programs")
    .select("*")
    .eq("id", values.primary_program_id)
    .maybeSingle();

  if (programError || !program || program.is_active === false) {
    return validationError(values, {
      primary_program_id: "El programa seleccionado no está disponible.",
    });
  }

  const requestHeaders = await headers();
  const origin = getSiteOrigin(
    requestHeaders.get("origin"),
    requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host"),
    requestHeaders.get("x-forwarded-proto"),
  );
  const emailRedirectTo = new URL("/auth/confirm", origin).toString();
  const { error } = await supabase.auth.signUp({
    email: values.email,
    password: safePassword,
    options: {
      emailRedirectTo,
      data: {
        sitaa_registration_type: personType,
        full_name: values.full_name,
        primary_program_id: values.primary_program_id,
        institutional_id_value: values.institutional_id_value,
      },
    },
  });

  if (error) {
    const mapped = mapSignUpError(error.message, error.code);
    return validationError(
      values,
      mapped.field ? { [mapped.field]: mapped.message } : {},
      mapped.message,
    );
  }

  redirect("/register/check-email");
}
