"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  AdminAccountLifecycleDataError,
  getAdminAccountLifecycleContext,
  runAdminAccountAuthLifecycle,
  transitionAdminAccountLifecycleLegacyBeforeB3a,
} from "@/lib/admin/account-lifecycle";
import { canAccessAccountAdministration } from "@/lib/admin/authorization";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import type { AdminAccountLifecycleTransition } from "@/types/admin";

export interface AccountLifecycleValues {
  mode: "start" | "retry";
  target_profile_id: string;
  transition: string;
  transition_reason: string;
  request_id: string;
  operation_id: string;
  confirmation: boolean;
}

export interface AccountLifecycleState {
  status: "idle" | "error" | "pending" | "terminal_failure";
  message: string | null;
  fieldErrors: Partial<Record<"transition_reason" | "confirmation", string>>;
  values: AccountLifecycleValues;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function textValue(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value : "";
}
function normalizedText(value: string) {
  return value.replace(/\s+/g, " ").trim();
}
function valuesFrom(formData: FormData): AccountLifecycleValues {
  return {
    mode: textValue(formData, "mode") === "retry" ? "retry" : "start",
    target_profile_id: textValue(formData, "target_profile_id"),
    transition: textValue(formData, "transition"),
    transition_reason: textValue(formData, "transition_reason"),
    request_id: textValue(formData, "request_id"),
    operation_id: textValue(formData, "operation_id"),
    confirmation: formData.get("confirmation") === "confirmed",
  };
}
function state(
  values: AccountLifecycleValues,
  status: AccountLifecycleState["status"],
  message: string,
  fieldErrors: AccountLifecycleState["fieldErrors"] = {},
): AccountLifecycleState {
  return { status, message, fieldErrors, values };
}

function mappedActionError(error: AdminAccountLifecycleDataError, values: AccountLifecycleValues) {
  const messages: Record<AdminAccountLifecycleDataError["kind"], string> = {
    migration_pending: "La gestión del estado estará disponible cuando se aplique la migración correspondiente.",
    forbidden: "No tienes permiso para cambiar el estado de esta cuenta.",
    self_forbidden: "No puedes desactivar ni reactivar tu propia cuenta administrativa.",
    target_unavailable: "La cuenta solicitada no está disponible.",
    pending_target: "Una cuenta con registro pendiente debe completar su propio registro.",
    invalid_transition: "La transición solicitada no es válida.",
    state_conflict: "El estado de la cuenta cambió. Actualiza la página antes de continuar.",
    invalid_identity: "La identidad de esta cuenta no cumple el contrato necesario para reactivarla.",
    auth_unconfirmed: "La cuenta de acceso no tiene un correo confirmado y no puede reactivarse.",
    last_admin: "No puedes desactivar la última cuenta con autoridad administrativa B.1.",
    invalid_reason: "El motivo administrativo no cumple el formato requerido.",
    operation_pending: "La sincronización con Auth está pendiente. Puedes reintentar la operación de forma segura.",
    terminal_failure: "La sincronización con Auth terminó con una incidencia que requiere revisión técnica.",
    trusted_boundary_unavailable: "El servicio confiable de sincronización Auth no está disponible. No se realizó una transición alternativa.",
    unavailable: "No fue posible cambiar el estado de la cuenta. Intenta nuevamente más tarde.",
  };
  return state(values, "error", messages[error.kind],
    error.kind === "invalid_reason" ? { transition_reason: messages[error.kind] } : {});
}

function edgeMessage(code: string) {
  const messages: Record<string, string> = {
    auth_temporarily_unavailable: "Supabase Auth no respondió temporalmente. La operación puede reintentarse sin repetir cambios completados.",
    auth_rate_limited: "Supabase Auth limitó temporalmente la operación. Intenta nuevamente más tarde.",
    auth_user_not_found: "No fue posible localizar de forma confiable la cuenta Auth asociada.",
    auth_update_rejected: "Supabase Auth rechazó la sincronización solicitada.",
    unsupported_auth_contract: "La restauración Auth no está disponible con el contrato instalado.",
    database_finalize_pending: "Auth ya fue sincronizado, pero la finalización en SITAA está pendiente. Reintenta para completar el proceso.",
    operation_processing: "La operación está siendo procesada. Actualiza la página antes de intentar nuevamente.",
    operation_unavailable: "La operación coordinada ya no está disponible.",
    authorization_lost: "Tu autorización administrativa cambió antes de completar la operación.",
    request_id_conflict: "El identificador de la solicitud ya corresponde a otra operación.",
    pending_target: "Una cuenta con registro pendiente debe completar su propio registro.",
    operation_in_progress: "Ya existe una operación coordinada no final para esta cuenta.",
    state_conflict: "El estado de la cuenta cambió. Actualiza la página antes de continuar.",
    database_contract_rejected: "La base de datos rechazó la operación coordinada.",
    malformed_database_response: "La respuesta del contrato coordinado no fue válida.",
    operation_terminal_failure: "La operación terminó con una incidencia que requiere revisión técnica.",
    result_persistence_failed: "La sincronización necesita reconciliación antes de continuar.",
    trusted_boundary_unavailable: "El servicio confiable de sincronización Auth no está disponible.",
    unexpected_failure: "La operación quedó pendiente por una incidencia temporal del límite confiable.",
  };
  return messages[code] ?? "La operación de cuenta no pudo completarse.";
}

export async function submitAccountLifecycleTransition(
  _previousState: AccountLifecycleState,
  formData: FormData,
): Promise<AccountLifecycleState> {
  const values = valuesFrom(formData);
  let actorContext;
  try {
    actorContext = await getAuthenticatedUserContext();
  } catch {
    return state(values, "error", "No fue posible validar tu sesión administrativa.");
  }
  if (!actorContext || !canAccessAccountAdministration(actorContext)) {
    return mappedActionError(new AdminAccountLifecycleDataError("forbidden"), values);
  }
  if (!UUID_PATTERN.test(values.target_profile_id)) return state(values, "error", "La cuenta solicitada no está disponible.");
  if (values.transition !== "deactivate" && values.transition !== "reactivate") {
    return mappedActionError(new AdminAccountLifecycleDataError("invalid_transition"), values);
  }
  if (values.mode === "retry" && !UUID_PATTERN.test(values.operation_id)) {
    return state(values, "error", "La operación pendiente no está disponible.");
  }

  const reason = normalizedText(values.transition_reason);
  if (values.mode === "start") {
    const fieldErrors: AccountLifecycleState["fieldErrors"] = {};
    if (!UUID_PATTERN.test(values.request_id)) return state(values, "error", "No fue posible generar el identificador seguro de la solicitud.");
    if (reason.length < 10 || reason.length > 1000) fieldErrors.transition_reason = "El motivo debe contener entre 10 y 1000 caracteres.";
    if (!values.confirmation) fieldErrors.confirmation = "Confirma la transición antes de continuar.";
    if (Object.keys(fieldErrors).length) return state(values, "error", "Revisa los campos señalados antes de continuar.", fieldErrors);
  }

  let completed = false;
  try {
    const context = await getAdminAccountLifecycleContext(values.target_profile_id);
    if (!context) return mappedActionError(new AdminAccountLifecycleDataError("target_unavailable"), values);

    if (values.mode === "retry") {
      if (!context.b3aAvailable || context.currentOperationId !== values.operation_id
        || context.operationCode !== values.transition || !context.canRetryOrFinalize) {
        return state(values, "error", "La operación ya no puede reintentarse desde este estado.");
      }
      const result = await runAdminAccountAuthLifecycle({ mode: "retry", operationId: values.operation_id });
      if (result.state === "completed") completed = true;
      else return state(
        { ...values, mode: "retry", operation_id: result.operationId ?? values.operation_id },
        result.state === "terminal_failure" ? "terminal_failure"
          : result.state === "rejected" ? "error" : "pending",
        edgeMessage(result.code),
      );
    } else {
      const allowed = values.transition === "deactivate" ? context.canDeactivate : context.canReactivate;
      if (!allowed) {
        const kind = context.denialCode === "self_forbidden" ? "self_forbidden"
          : context.denialCode === "pending_target" ? "pending_target"
          : context.denialCode === "last_admin" ? "last_admin"
          : context.denialCode === "invalid_identity" ? "invalid_identity"
          : context.denialCode === "auth_unconfirmed" ? "auth_unconfirmed" : "state_conflict";
        return mappedActionError(new AdminAccountLifecycleDataError(kind), values);
      }
      if (context.b3aAvailable) {
        const result = await runAdminAccountAuthLifecycle({
          mode: "start", targetProfileId: values.target_profile_id,
          transition: values.transition as AdminAccountLifecycleTransition,
          reason, requestId: values.request_id,
        });
        if (result.state === "completed") completed = true;
        else {
          const nextValues = result.operationId
            ? { ...values, mode: "retry" as const, operation_id: result.operationId }
            : values;
          return state(
            nextValues,
            result.state === "terminal_failure" ? "terminal_failure"
              : result.state === "rejected" ? "error" : "pending",
            edgeMessage(result.code),
          );
        }
      } else {
        await transitionAdminAccountLifecycleLegacyBeforeB3a({
          targetProfileId: values.target_profile_id,
          transition: values.transition as AdminAccountLifecycleTransition,
          reason, requestId: values.request_id,
        });
        completed = true;
      }
    }
  } catch (error) {
    return error instanceof AdminAccountLifecycleDataError
      ? mappedActionError(error, values)
      : state(values, "error", "No fue posible cambiar el estado de la cuenta. Intenta nuevamente más tarde.");
  }

  if (!completed) return state(values, "error", "La operación no alcanzó un estado final válido.");
  revalidatePath("/admin/accounts");
  revalidatePath("/dashboard");
  revalidatePath("/account-status");
  revalidatePath(`/admin/accounts/${values.target_profile_id}`);
  revalidatePath(`/admin/accounts/${values.target_profile_id}/lifecycle`);
  redirect(`/admin/accounts/${values.target_profile_id}?lifecycle=${
    values.transition === "deactivate" ? "deactivated" : "reactivated"
  }`);
}
