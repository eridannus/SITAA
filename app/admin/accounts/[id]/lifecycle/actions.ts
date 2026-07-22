"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  AdminAccountLifecycleDataError,
  getAdminAccountLifecycleContext,
  transitionAdminAccountLifecycle,
} from "@/lib/admin/account-lifecycle";
import { canAccessAccountAdministration } from "@/lib/admin/authorization";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import type { AdminAccountLifecycleTransition } from "@/types/admin";

export interface AccountLifecycleValues {
  target_profile_id: string;
  transition: string;
  transition_reason: string;
  confirmation: boolean;
}

export interface AccountLifecycleState {
  status: "idle" | "error";
  message: string | null;
  fieldErrors: Partial<
    Record<"transition_reason" | "confirmation", string>
  >;
  values: AccountLifecycleValues;
}

function textValue(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value : "";
}

function normalizedText(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function valuesFrom(formData: FormData): AccountLifecycleValues {
  return {
    target_profile_id: textValue(formData, "target_profile_id"),
    transition: textValue(formData, "transition"),
    transition_reason: textValue(formData, "transition_reason"),
    confirmation: formData.get("confirmation") === "confirmed",
  };
}

function errorState(
  values: AccountLifecycleValues,
  message: string,
  fieldErrors: AccountLifecycleState["fieldErrors"] = {},
): AccountLifecycleState {
  return { status: "error", message, fieldErrors, values };
}

function mappedActionError(
  error: AdminAccountLifecycleDataError,
  values: AccountLifecycleValues,
): AccountLifecycleState {
  const messages: Record<AdminAccountLifecycleDataError["kind"], string> = {
    migration_pending:
      "La gestión del estado estará disponible cuando se aplique la migración 0009.",
    forbidden: "No tienes permiso para cambiar el estado de esta cuenta.",
    self_forbidden:
      "No puedes desactivar ni reactivar tu propia cuenta administrativa.",
    target_unavailable: "La cuenta solicitada no está disponible.",
    pending_target:
      "Una cuenta con registro pendiente debe completar su propio registro.",
    invalid_transition: "La transición solicitada no es válida.",
    state_conflict:
      "El estado de la cuenta cambió. Actualiza la página antes de continuar.",
    invalid_identity:
      "La identidad de esta cuenta no cumple el contrato necesario para reactivarla.",
    auth_unconfirmed:
      "La cuenta de acceso no tiene un correo confirmado y no puede reactivarse.",
    last_admin:
      "No puedes desactivar la última cuenta con autoridad administrativa B.1.",
    invalid_reason: "El motivo administrativo no cumple el formato requerido.",
    unavailable:
      "No fue posible cambiar el estado de la cuenta. Intenta nuevamente más tarde.",
  };
  const fieldErrors = error.kind === "invalid_reason"
    ? { transition_reason: messages[error.kind] }
    : {};
  return errorState(values, messages[error.kind], fieldErrors);
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
    return errorState(values, "No fue posible validar tu sesión administrativa.");
  }
  if (!actorContext || !canAccessAccountAdministration(actorContext)) {
    return mappedActionError(
      new AdminAccountLifecycleDataError("forbidden"),
      values,
    );
  }

  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      values.target_profile_id,
    )
  ) {
    return errorState(values, "La cuenta solicitada no está disponible.");
  }
  if (values.transition !== "deactivate" && values.transition !== "reactivate") {
    return mappedActionError(
      new AdminAccountLifecycleDataError("invalid_transition"),
      values,
    );
  }

  const reason = normalizedText(values.transition_reason);
  const fieldErrors: AccountLifecycleState["fieldErrors"] = {};
  if (reason.length < 10 || reason.length > 1000) {
    fieldErrors.transition_reason =
      "El motivo debe contener entre 10 y 1000 caracteres.";
  }
  if (!values.confirmation) {
    fieldErrors.confirmation = "Confirma la transición antes de continuar.";
  }
  if (Object.keys(fieldErrors).length) {
    return errorState(
      values,
      "Revisa los campos señalados antes de continuar.",
      fieldErrors,
    );
  }

  try {
    const context = await getAdminAccountLifecycleContext(
      values.target_profile_id,
    );
    if (!context) {
      return mappedActionError(
        new AdminAccountLifecycleDataError("target_unavailable"),
        values,
      );
    }
    const allowed = values.transition === "deactivate"
      ? context.canDeactivate
      : context.canReactivate;
    if (!allowed) {
      const kind = context.denialCode === "self_forbidden"
        ? "self_forbidden"
        : context.denialCode === "pending_target"
          ? "pending_target"
          : context.denialCode === "last_admin"
            ? "last_admin"
            : context.denialCode === "invalid_identity"
              ? "invalid_identity"
              : context.denialCode === "auth_unconfirmed"
                ? "auth_unconfirmed"
                : "state_conflict";
      return mappedActionError(new AdminAccountLifecycleDataError(kind), values);
    }

    await transitionAdminAccountLifecycle({
      targetProfileId: values.target_profile_id,
      transition: values.transition as AdminAccountLifecycleTransition,
      reason,
    });
  } catch (error) {
    return error instanceof AdminAccountLifecycleDataError
      ? mappedActionError(error, values)
      : errorState(
          values,
          "No fue posible cambiar el estado de la cuenta. Intenta nuevamente más tarde.",
        );
  }

  revalidatePath("/admin/accounts");
  revalidatePath("/dashboard");
  revalidatePath("/account-status");
  revalidatePath(`/admin/accounts/${values.target_profile_id}`);
  revalidatePath(`/admin/accounts/${values.target_profile_id}/lifecycle`);
  redirect(
    `/admin/accounts/${values.target_profile_id}?lifecycle=${
      values.transition === "deactivate" ? "deactivated" : "reactivated"
    }`,
  );
}
