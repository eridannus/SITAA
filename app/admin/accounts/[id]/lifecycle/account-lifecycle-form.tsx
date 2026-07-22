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
} from "@/types/admin";

function SubmitButton({ transition }: { transition: AdminAccountLifecycleTransition }) {
  const { pending } = useFormStatus();
  const label = transition === "deactivate" ? "Desactivar cuenta" : "Reactivar cuenta";
  return (
    <button type="submit" disabled={pending} className="sitaa-primary-action w-full sm:w-auto">
      {pending ? "Guardando…" : label}
    </button>
  );
}

export function AccountLifecycleForm({
  detail,
  context,
  transition,
}: {
  detail: AdminAccountDetail;
  context: AdminAccountLifecycleContext;
  transition: AdminAccountLifecycleTransition;
}) {
  const initialState: AccountLifecycleState = {
    status: "idle",
    message: null,
    fieldErrors: {},
    values: {
      target_profile_id: detail.profileId,
      transition,
      transition_reason: "",
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
      else if (state.fieldErrors.confirmation) {
        document.getElementById("confirmation")?.focus();
      }
    }
  }, [state]);

  const isDeactivate = transition === "deactivate";
  return (
    <form action={formAction} className="mt-8 grid gap-6" noValidate>
      <input type="hidden" name="target_profile_id" value={detail.profileId} />
      <input type="hidden" name="transition" value={transition} />

      {state.message ? (
        <div role="alert" className="sitaa-alert sitaa-alert--error">
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
            ? "La cuenta perderá acceso operativo inmediatamente."
            : "La cuenta recuperará el acceso operativo de acuerdo con sus asignaciones vigentes."}
        </p>
        <p className="mt-2 text-sm">
          {isDeactivate
            ? "La cuenta no se elimina: sus asignaciones, actividades, participaciones y el historial se conservan. Esta fase no revoca físicamente todas las sesiones Auth ya emitidas."
            : "Sólo las asignaciones que sigan vigentes y activas recuperarán efecto. Las asignaciones vencidas o inactivas continuarán sin autorización; la identidad y Auth deben ser válidos."}
        </p>
      </div>

      {(context.currentOrFutureAssignmentCount > 0 ||
        context.openResponsibilityCount > 0 ||
        context.openParticipationCount > 0) ? (
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
          required
          minLength={10}
          maxLength={1000}
          rows={5}
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
            key={String(state.values.confirmation)}
            id="confirmation"
            name="confirmation"
            type="checkbox"
            value="confirmed"
            defaultChecked={state.values.confirmation}
            className="sitaa-checkbox mt-1 h-5 w-5 shrink-0"
            aria-invalid={Boolean(state.fieldErrors.confirmation)}
            aria-describedby={state.fieldErrors.confirmation ? "confirmation-error" : undefined}
          />
          <span>
            Confirmo que revisé la cuenta y deseo {isDeactivate ? "desactivarla" : "reactivarla"}.
          </span>
        </label>
        {state.fieldErrors.confirmation ? (
          <p id="confirmation-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">
            {state.fieldErrors.confirmation}
          </p>
        ) : null}
      </div>

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Link href={`/admin/accounts/${detail.profileId}`} className="sitaa-secondary-action w-full sm:w-auto">Cancelar</Link>
        <SubmitButton transition={transition} />
      </div>
    </form>
  );
}
