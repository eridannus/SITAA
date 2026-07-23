"use client";

import Link from "next/link";
import { useActionState, useEffect, useRef } from "react";
import { useFormStatus } from "react-dom";
import {
  submitAccountLifecycleTransition,
  type AccountLifecycleState,
} from "./actions";
import type {
  AdminAccountDetail,
  AdminAccountLifecycleContext,
  AdminAccountLifecycleTransition,
  AdminAuthOperationStage,
} from "@/types/admin";

function SubmitButton({ transition, retry }: {
  transition: AdminAccountLifecycleTransition;
  retry?: boolean;
}) {
  const { pending } = useFormStatus();
  const label = retry ? "Reintentar sincronización"
    : transition === "deactivate" ? "Desactivar cuenta" : "Reactivar cuenta";
  return (
    <button type="submit" disabled={pending} className="sitaa-primary-action w-full sm:w-auto">
      {pending ? "Procesando…" : label}
    </button>
  );
}

const stageLabels: Record<AdminAuthOperationStage, string> = {
  prepared: "Operación preparada; el perfil todavía no se reactiva.",
  profile_suspended: "El perfil ya está suspendido; falta sincronizar Supabase Auth.",
  auth_synchronized: "Supabase Auth ya fue sincronizado; falta la finalización en SITAA.",
  completed: "La operación quedó completamente coordinada.",
};

export function AccountLifecycleForm({ detail, context, transition, requestId }: {
  detail: AdminAccountDetail;
  context: AdminAccountLifecycleContext;
  transition: AdminAccountLifecycleTransition;
  requestId: string;
}) {
  const initialState: AccountLifecycleState = {
    status: context.operationStatus === "terminal_failure" ? "terminal_failure"
      : context.openOperationId ? "pending" : "idle",
    message: context.operationStatus === "terminal_failure"
      ? "La sincronización terminó con una incidencia que requiere revisión técnica."
      : context.openOperationId ? "Existe una operación coordinada pendiente para esta cuenta." : null,
    fieldErrors: {},
    values: {
      mode: context.openOperationId ? "retry" : "start",
      target_profile_id: detail.profileId,
      transition,
      transition_reason: "",
      request_id: requestId,
      operation_id: context.openOperationId ?? "",
      confirmation: false,
    },
  };
  const [state, formAction] = useActionState<AccountLifecycleState, FormData>(
    submitAccountLifecycleTransition,
    initialState,
  );
  const reasonRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (state.status === "error") {
      if (state.fieldErrors.transition_reason) reasonRef.current?.focus();
      else if (state.fieldErrors.confirmation) document.getElementById("confirmation")?.focus();
    }
  }, [state]);

  const isDeactivate = transition === "deactivate";
  const operationId = state.values.operation_id || context.openOperationId;
  const operationPending = Boolean(operationId);
  const operationTerminal = state.status === "terminal_failure" || context.operationStatus === "terminal_failure";
  const canRetry = !operationTerminal && (
    state.status === "pending" || context.canRetryOrFinalize
  );
  const currentStage = context.completedStage;

  return (
    <form action={formAction} className="mt-8 grid gap-6" noValidate>
      <input type="hidden" name="mode" value={operationPending ? "retry" : "start"} />
      <input type="hidden" name="target_profile_id" value={detail.profileId} />
      <input type="hidden" name="transition" value={transition} />
      <input type="hidden" name="request_id" value={state.values.request_id} />
      <input type="hidden" name="operation_id" value={operationId ?? ""} />

      {state.message ? (
        <div role="alert" className={`sitaa-alert ${
          state.status === "pending" ? "sitaa-alert--warning" : "sitaa-alert--error"
        }`}>
          <p className="font-semibold">{state.message}</p>
          {Object.entries(state.fieldErrors).length ? (
            <ul className="mt-3 list-disc space-y-1 pl-5">
              {Object.entries(state.fieldErrors).map(([field, message]) => (
                <li key={field}><a className="underline" href={`#${field}`}>{message}</a></li>
              ))}
            </ul>
          ) : null}
        </div>
      ) : null}

      <div className="sitaa-alert sitaa-alert--warning">
        <p className="font-semibold">
          {isDeactivate
            ? "El bloqueo operativo de SITAA se aplica inmediatamente al suspender el perfil."
            : "El perfil permanecerá inactivo hasta que Auth se restaure y la finalización en SITAA sea válida."}
        </p>
        <p className="mt-2 text-sm">
          Los JWT de acceso ya emitidos pueden conservar validez técnica hasta expirar, pero la barrera 0008 deniega operaciones mientras el perfil esté inactivo. No se elimina identidad, asignación, actividad, participación, asistencia ni historial.
        </p>
      </div>

      {operationPending ? (
        <section className="sitaa-card p-5" aria-labelledby="operation-state-heading">
          <h2 id="operation-state-heading" className="font-bold text-[var(--sitaa-blue-dark)]">
            Sincronización coordinada
          </h2>
          <p className="mt-2 text-sm">
            {currentStage ? stageLabels[currentStage] : "La operación conserva el último avance confirmado y no repetirá una transición persistida."}
          </p>
          <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
            <div><dt className="font-semibold">Estado</dt><dd>{operationTerminal ? "Fallo terminal" : "Pendiente"}</dd></div>
            <div><dt className="font-semibold">Intentos registrados</dt><dd>{context.attemptCount}</dd></div>
          </dl>
          {canRetry ? (
            <div className="mt-5 flex justify-end"><SubmitButton transition={transition} retry /></div>
          ) : operationTerminal ? (
            <p className="mt-4 text-sm">La operación no admite reintento automático. Solicita revisión técnica.</p>
          ) : (
            <p className="mt-4 text-sm">La operación está siendo procesada. Actualiza la página antes de intentar nuevamente.</p>
          )}
        </section>
      ) : (
        <>
          {(context.currentOrFutureAssignmentCount > 0 || context.openResponsibilityCount > 0 || context.openParticipationCount > 0) ? (
            <div className="sitaa-card p-5">
              <h2 className="font-bold text-[var(--sitaa-blue-dark)]">Dependencias conservadas</h2>
              <ul className="mt-3 space-y-1 text-sm">
                <li>Asignaciones actuales o futuras: {context.currentOrFutureAssignmentCount}</li>
                <li>Responsabilidades abiertas: {context.openResponsibilityCount}</li>
                <li>Participaciones abiertas: {context.openParticipationCount}</li>
              </ul>
            </div>
          ) : null}

          <div className="min-w-0">
            <label htmlFor="transition_reason" className="sitaa-form-label">Motivo administrativo</label>
            <textarea
              ref={reasonRef}
              key={state.values.transition_reason}
              id="transition_reason"
              name="transition_reason"
              required minLength={10} maxLength={1000} rows={5}
              defaultValue={state.values.transition_reason}
              className={`sitaa-field mt-2 ${state.fieldErrors.transition_reason ? "sitaa-field-invalid" : ""}`}
              aria-invalid={Boolean(state.fieldErrors.transition_reason)}
              aria-describedby="transition_reason-help transition_reason-error"
            />
            <p id="transition_reason-help" className="sitaa-help-text mt-2">
              Escribe entre 10 y 1000 caracteres. No incluyas contraseñas, tokens ni datos sensibles innecesarios.
            </p>
            {state.fieldErrors.transition_reason ? (
              <p id="transition_reason-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">
                {state.fieldErrors.transition_reason}
              </p>
            ) : null}
          </div>

          <div>
            <label className="flex min-h-11 cursor-pointer items-start gap-3">
              <input
                key={String(state.values.confirmation)} id="confirmation" name="confirmation"
                type="checkbox" value="confirmed" defaultChecked={state.values.confirmation}
                className="sitaa-checkbox mt-1 h-5 w-5 shrink-0"
                aria-invalid={Boolean(state.fieldErrors.confirmation)}
                aria-describedby={state.fieldErrors.confirmation ? "confirmation-error" : undefined}
              />
              <span>Confirmo que revisé la cuenta y deseo {isDeactivate ? "desactivarla" : "reactivarla"}.</span>
            </label>
            {state.fieldErrors.confirmation ? (
              <p id="confirmation-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">
                {state.fieldErrors.confirmation}
              </p>
            ) : null}
          </div>
        </>
      )}

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Link href={`/admin/accounts/${detail.profileId}`} className="sitaa-secondary-action w-full sm:w-auto">Cancelar</Link>
        {!operationPending ? <SubmitButton transition={transition} /> : null}
      </div>
    </form>
  );
}
