"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { canAccessAccountAdministration } from "@/lib/admin/authorization";
import {
  AdminIdentityCorrectionDataError,
  correctAdminAccountIdentity,
  getAdminIdentityCorrectionContext,
} from "@/lib/admin/identity-correction";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import type { AccountKind, PersonType } from "@/types/sitaa";

export type IdentityCorrectionField =
  | "first_names"
  | "paternal_surname"
  | "maternal_surname"
  | "person_type"
  | "institutional_id_value"
  | "primary_program_id"
  | "correction_reason"
  | "confirmation";

export interface IdentityCorrectionValues {
  target_profile_id: string;
  first_names: string;
  paternal_surname: string;
  maternal_surname: string;
  person_type: string;
  institutional_id_value: string;
  primary_program_id: string;
  correction_reason: string;
  confirmation: boolean;
}

export interface IdentityCorrectionState {
  status: "idle" | "error";
  message: string | null;
  fieldErrors: Partial<Record<IdentityCorrectionField, string>>;
  values: IdentityCorrectionValues;
}

function textValue(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value : "";
}

function normalizedText(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function valuesFrom(formData: FormData): IdentityCorrectionValues {
  return {
    target_profile_id: textValue(formData, "target_profile_id"),
    first_names: textValue(formData, "first_names"),
    paternal_surname: textValue(formData, "paternal_surname"),
    maternal_surname: textValue(formData, "maternal_surname"),
    person_type: textValue(formData, "person_type"),
    institutional_id_value: textValue(
      formData,
      "institutional_id_value",
    ),
    primary_program_id: textValue(formData, "primary_program_id"),
    correction_reason: textValue(formData, "correction_reason"),
    confirmation: formData.get("confirmation") === "verified",
  };
}

function validateNames(
  values: IdentityCorrectionValues,
  accountKind: AccountKind,
  errors: IdentityCorrectionState["fieldErrors"],
) {
  const firstNames = normalizedText(values.first_names);
  const paternalSurname = normalizedText(values.paternal_surname);
  const maternalSurname = normalizedText(values.maternal_surname);
  const fullName = [firstNames, paternalSurname, maternalSurname]
    .filter(Boolean)
    .join(" ");

  if (!firstNames || firstNames.length > 150) {
    errors.first_names = "Indica nombre(s) de hasta 150 caracteres.";
  }
  if (
    (accountKind === "institutional" && !paternalSurname) ||
    paternalSurname.length > 150
  ) {
    errors.paternal_surname = accountKind === "institutional"
      ? "El apellido paterno es obligatorio y admite hasta 150 caracteres."
      : "El apellido paterno admite hasta 150 caracteres.";
  }
  if (maternalSurname.length > 150) {
    errors.maternal_surname =
      "El apellido materno admite hasta 150 caracteres.";
  }
  if (fullName.length < 2 || fullName.length > 200) {
    errors.first_names =
      "El nombre completo debe contener entre 2 y 200 caracteres.";
  }
}

function validateInstitutionalFields(
  values: IdentityCorrectionValues,
  errors: IdentityCorrectionState["fieldErrors"],
) {
  if (values.person_type !== "student" && values.person_type !== "professor") {
    errors.person_type = "Selecciona Alumno o Profesor.";
  }
  const identifier = normalizedText(values.institutional_id_value);
  if (!/^[0-9]{1,50}$/.test(identifier)) {
    errors.institutional_id_value =
      "Escribe entre 1 y 50 dígitos, sin espacios ni símbolos.";
  }
  if (!values.primary_program_id) {
    errors.primary_program_id = "Selecciona un programa académico activo.";
  }
}

function errorState(
  values: IdentityCorrectionValues,
  message: string,
  fieldErrors: IdentityCorrectionState["fieldErrors"] = {},
): IdentityCorrectionState {
  return { status: "error", message, fieldErrors, values };
}

function mappedActionError(
  error: AdminIdentityCorrectionDataError,
  values: IdentityCorrectionValues,
): IdentityCorrectionState {
  const fieldErrors: IdentityCorrectionState["fieldErrors"] = {};
  const messages: Record<
    AdminIdentityCorrectionDataError["kind"],
    string
  > = {
    migration_pending:
      "La corrección de identidad estará disponible cuando se aplique la migración 0008.",
    forbidden: "No tienes permiso para corregir esta identidad.",
    self_forbidden:
      "No puedes usar esta operación administrativa sobre tu propia cuenta.",
    pending_target:
      "Una cuenta con registro pendiente debe completar su propio registro.",
    invalid_name: "Revisa los nombres y apellidos capturados.",
    invalid_person_type: "El tipo de persona no es válido.",
    invalid_identifier: "El identificador institucional no es válido.",
    duplicate_identifier:
      "El identificador institucional ya pertenece a otra cuenta.",
    invalid_program: "El programa seleccionado no existe o está inactivo.",
    technical_fields_forbidden:
      "Una cuenta técnica sólo permite corregir nombres y apellidos.",
    no_changes: "No hay cambios de identidad para guardar.",
    invalid_reason: "El motivo administrativo no cumple el formato requerido.",
    person_type_dependency:
      "No puede cambiarse el tipo de persona mientras existan asignaciones o responsabilidades abiertas.",
    program_dependency:
      "No puede cambiarse el programa mientras existan asignaciones, responsabilidades o participaciones incompatibles.",
    unavailable:
      "No fue posible guardar la corrección. Intenta nuevamente más tarde.",
  };

  if (error.kind === "invalid_name") fieldErrors.first_names = messages[error.kind];
  if (error.kind === "invalid_person_type") fieldErrors.person_type = messages[error.kind];
  if (error.kind === "invalid_identifier" || error.kind === "duplicate_identifier") {
    fieldErrors.institutional_id_value = messages[error.kind];
  }
  if (error.kind === "invalid_program") fieldErrors.primary_program_id = messages[error.kind];
  if (error.kind === "invalid_reason") fieldErrors.correction_reason = messages[error.kind];

  return errorState(values, messages[error.kind], fieldErrors);
}

export async function submitIdentityCorrection(
  _previousState: IdentityCorrectionState,
  formData: FormData,
): Promise<IdentityCorrectionState> {
  const values = valuesFrom(formData);

  let actorContext;
  try {
    actorContext = await getAuthenticatedUserContext();
  } catch {
    return errorState(values, "No fue posible validar tu sesión administrativa.");
  }
  if (!actorContext || !canAccessAccountAdministration(actorContext)) {
    return mappedActionError(
      new AdminIdentityCorrectionDataError("forbidden"),
      values,
    );
  }

  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(values.target_profile_id)) {
    return errorState(values, "La cuenta solicitada no está disponible.");
  }

  let context;
  try {
    context = await getAdminIdentityCorrectionContext(values.target_profile_id);
  } catch (error) {
    return error instanceof AdminIdentityCorrectionDataError
      ? mappedActionError(error, values)
      : errorState(values, "No fue posible validar esta corrección.");
  }

  if (!context) {
    return errorState(values, "La cuenta solicitada no está disponible.");
  }
  if (!context.canCorrect) {
    const kind = context.isSelf
      ? "self_forbidden"
      : context.accountStatus === "pending_registration"
        ? "pending_target"
        : "unavailable";
    return mappedActionError(new AdminIdentityCorrectionDataError(kind), values);
  }

  const fieldErrors: IdentityCorrectionState["fieldErrors"] = {};
  validateNames(values, context.accountKind, fieldErrors);
  if (context.accountKind === "institutional") {
    validateInstitutionalFields(values, fieldErrors);
  }
  const reason = normalizedText(values.correction_reason);
  if (reason.length < 10 || reason.length > 1000) {
    fieldErrors.correction_reason =
      "El motivo debe contener entre 10 y 1000 caracteres.";
  }
  if (!values.confirmation) {
    fieldErrors.confirmation =
      "Confirma que verificaste la información fuente.";
  }
  if (Object.keys(fieldErrors).length) {
    return errorState(
      values,
      "Revisa los campos señalados antes de guardar.",
      fieldErrors,
    );
  }

  const personType = context.accountKind === "institutional"
    ? (values.person_type as PersonType)
    : null;
  try {
    await correctAdminAccountIdentity({
      targetProfileId: values.target_profile_id,
      firstNames: normalizedText(values.first_names),
      paternalSurname: normalizedText(values.paternal_surname) || null,
      maternalSurname: normalizedText(values.maternal_surname) || null,
      personType,
      institutionalIdValue: context.accountKind === "institutional"
        ? normalizedText(values.institutional_id_value)
        : null,
      primaryProgramId: context.accountKind === "institutional"
        ? values.primary_program_id
        : null,
      reason,
    });
  } catch (error) {
    return error instanceof AdminIdentityCorrectionDataError
      ? mappedActionError(error, values)
      : errorState(
          values,
          "No fue posible guardar la corrección. Intenta nuevamente más tarde.",
        );
  }

  revalidatePath(`/admin/accounts/${values.target_profile_id}`);
  revalidatePath(`/admin/accounts/${values.target_profile_id}/identity`);
  redirect(`/admin/accounts/${values.target_profile_id}?identity=corrected`);
}
