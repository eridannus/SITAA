"use client";

import { useActionState, useEffect, useRef } from "react";
import { useFormStatus } from "react-dom";
import Link from "next/link";
import {
  submitIdentityCorrection,
  type IdentityCorrectionField,
  type IdentityCorrectionState,
} from "./actions";
import type { AdminAccountDetail, AdminFilterOption } from "@/types/admin";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="sitaa-primary-action w-full sm:w-auto"
    >
      {pending ? "Guardando…" : "Guardar corrección"}
    </button>
  );
}

function fieldClass(error?: string) {
  return `sitaa-field mt-2 ${error ? "sitaa-field-invalid" : ""}`;
}

const fieldLabels: Record<IdentityCorrectionField, string> = {
  first_names: "Nombre(s)",
  paternal_surname: "Apellido paterno",
  maternal_surname: "Apellido materno",
  person_type: "Tipo de persona",
  institutional_id_value: "Identificador institucional",
  primary_program_id: "Programa académico principal",
  correction_reason: "Motivo administrativo",
  confirmation: "Confirmación de verificación",
};

function FieldError({
  id,
  message,
}: {
  id: string;
  message?: string;
}) {
  return message ? (
    <p id={id} className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">
      {message}
    </p>
  ) : null;
}

export function IdentityCorrectionForm({
  detail,
  programs,
}: {
  detail: AdminAccountDetail;
  programs: AdminFilterOption[];
}) {
  const initialState: IdentityCorrectionState = {
    status: "idle",
    message: null,
    fieldErrors: {},
    values: {
      target_profile_id: detail.profileId,
      first_names: detail.firstNames ?? "",
      paternal_surname: detail.paternalSurname ?? "",
      maternal_surname: detail.maternalSurname ?? "",
      person_type: detail.personType ?? "",
      institutional_id_value: detail.institutionalIdValue ?? "",
      primary_program_id: detail.primaryProgramId ?? "",
      correction_reason: "",
      confirmation: false,
    },
  };
  const [state, formAction] = useActionState<IdentityCorrectionState, FormData>(
    submitIdentityCorrection,
    initialState,
  );
  const reasonCountRef = useRef<HTMLParagraphElement>(null);
  const firstError = Object.keys(state.fieldErrors)[0] as
    | IdentityCorrectionField
    | undefined;
  const errorEntries = Object.entries(state.fieldErrors) as Array<
    [IdentityCorrectionField, string]
  >;
  const institutional = detail.accountKind === "institutional";

  useEffect(() => {
    if (state.status === "error" && firstError) {
      document.getElementById(firstError)?.focus();
    }
  }, [firstError, state.status]);

  return (
    <form action={formAction} className="mt-8 grid min-w-0 gap-6 sm:grid-cols-2" noValidate>
      <input type="hidden" name="target_profile_id" value={detail.profileId} />

      {state.message ? (
        <div role="alert" className="sitaa-alert sitaa-alert--error sm:col-span-2">
          <p className="font-semibold">{state.message}</p>
          {errorEntries.length ? (
            <ul className="mt-3 list-disc space-y-1 pl-5">
              {errorEntries.map(([field, message]) => (
                <li key={field}>
                  <a href={`#${field}`} className="underline underline-offset-2">
                    {fieldLabels[field]}: {message}
                  </a>
                </li>
              ))}
            </ul>
          ) : null}
        </div>
      ) : null}

      <div className="min-w-0 sm:col-span-2">
        <label htmlFor="first_names" className="sitaa-form-label">Nombre(s)</label>
        <input
          key={`first-${state.values.first_names}`}
          id="first_names"
          name="first_names"
          required
          maxLength={150}
          autoComplete="off"
          defaultValue={state.values.first_names}
          aria-invalid={Boolean(state.fieldErrors.first_names)}
          aria-describedby={state.fieldErrors.first_names ? "first_names-error" : undefined}
          className={fieldClass(state.fieldErrors.first_names)}
        />
        <FieldError id="first_names-error" message={state.fieldErrors.first_names} />
      </div>

      <div className="min-w-0">
        <label htmlFor="paternal_surname" className="sitaa-form-label">
          Apellido paterno {!institutional ? <span className="font-normal text-[var(--sitaa-text-secondary)]">(opcional)</span> : null}
        </label>
        <input
          key={`paternal-${state.values.paternal_surname}`}
          id="paternal_surname"
          name="paternal_surname"
          required={institutional}
          maxLength={150}
          autoComplete="off"
          defaultValue={state.values.paternal_surname}
          aria-invalid={Boolean(state.fieldErrors.paternal_surname)}
          aria-describedby={state.fieldErrors.paternal_surname ? "paternal_surname-error" : undefined}
          className={fieldClass(state.fieldErrors.paternal_surname)}
        />
        <FieldError id="paternal_surname-error" message={state.fieldErrors.paternal_surname} />
      </div>

      <div className="min-w-0">
        <label htmlFor="maternal_surname" className="sitaa-form-label">
          Apellido materno <span className="font-normal text-[var(--sitaa-text-secondary)]">(opcional)</span>
        </label>
        <input
          key={`maternal-${state.values.maternal_surname}`}
          id="maternal_surname"
          name="maternal_surname"
          maxLength={150}
          autoComplete="off"
          defaultValue={state.values.maternal_surname}
          aria-invalid={Boolean(state.fieldErrors.maternal_surname)}
          aria-describedby={state.fieldErrors.maternal_surname ? "maternal_surname-error" : undefined}
          className={fieldClass(state.fieldErrors.maternal_surname)}
        />
        <FieldError id="maternal_surname-error" message={state.fieldErrors.maternal_surname} />
      </div>

      {institutional ? (
        <>
          <div className="min-w-0">
            <label htmlFor="person_type" className="sitaa-form-label">Tipo de persona</label>
            <select
              key={`person-${state.values.person_type}`}
              id="person_type"
              name="person_type"
              required
              defaultValue={state.values.person_type}
              aria-invalid={Boolean(state.fieldErrors.person_type)}
              aria-describedby={state.fieldErrors.person_type ? "person_type-error" : undefined}
              className={fieldClass(state.fieldErrors.person_type)}
            >
              <option value="" disabled>Selecciona un tipo</option>
              <option value="student">Alumno</option>
              <option value="professor">Profesor</option>
            </select>
            <FieldError id="person_type-error" message={state.fieldErrors.person_type} />
          </div>

          <div className="min-w-0">
            <label htmlFor="institutional_id_value" className="sitaa-form-label">Identificador institucional</label>
            <input
              key={`identifier-${state.values.institutional_id_value}`}
              id="institutional_id_value"
              name="institutional_id_value"
              required
              inputMode="numeric"
              pattern="[0-9]+"
              maxLength={50}
              autoComplete="off"
              defaultValue={state.values.institutional_id_value}
              aria-invalid={Boolean(state.fieldErrors.institutional_id_value)}
              aria-describedby={state.fieldErrors.institutional_id_value ? "institutional_id_value-help institutional_id_value-error" : "institutional_id_value-help"}
              className={fieldClass(state.fieldErrors.institutional_id_value)}
            />
            <p id="institutional_id_value-help" className="sitaa-help-text mt-2">Usa sólo dígitos; los ceros iniciales se conservan.</p>
            <FieldError id="institutional_id_value-error" message={state.fieldErrors.institutional_id_value} />
          </div>

          <div className="min-w-0 sm:col-span-2">
            <label htmlFor="primary_program_id" className="sitaa-form-label">Programa académico principal</label>
            <select
              key={`program-${state.values.primary_program_id}`}
              id="primary_program_id"
              name="primary_program_id"
              required
              defaultValue={state.values.primary_program_id}
              aria-invalid={Boolean(state.fieldErrors.primary_program_id)}
              aria-describedby={state.fieldErrors.primary_program_id ? "primary_program_id-error" : undefined}
              className={fieldClass(state.fieldErrors.primary_program_id)}
            >
              <option value="" disabled>Selecciona un programa activo</option>
              {programs.map((program) => <option key={program.value} value={program.value}>{program.label}</option>)}
            </select>
            <FieldError id="primary_program_id-error" message={state.fieldErrors.primary_program_id} />
          </div>
        </>
      ) : null}

      <div className="min-w-0 sm:col-span-2">
        <label htmlFor="correction_reason" className="sitaa-form-label">Motivo administrativo</label>
        <textarea
          key={`reason-${state.values.correction_reason}`}
          id="correction_reason"
          name="correction_reason"
          required
          minLength={10}
          maxLength={1000}
          rows={5}
          defaultValue={state.values.correction_reason}
          onChange={(event) => {
            if (reasonCountRef.current) {
              reasonCountRef.current.textContent =
                `${event.currentTarget.value.length} de 1000 caracteres.`;
            }
          }}
          aria-invalid={Boolean(state.fieldErrors.correction_reason)}
          aria-describedby="correction_reason-help correction_reason-count correction_reason-error"
          className={fieldClass(state.fieldErrors.correction_reason)}
        />
        <p id="correction_reason-help" className="sitaa-help-text mt-2">
          Describe el motivo administrativo. No incluyas contraseñas, tokens, identificadores completos ni datos sensibles innecesarios.
        </p>
        <p ref={reasonCountRef} id="correction_reason-count" className="sitaa-help-text mt-1" aria-live="polite">
          {state.values.correction_reason.length} de 1000 caracteres.
        </p>
        <FieldError id="correction_reason-error" message={state.fieldErrors.correction_reason} />
      </div>

      <div className="min-w-0 sm:col-span-2">
        <label className="flex min-h-11 cursor-pointer items-start gap-3">
          <input
            key={`confirmation-${state.values.confirmation}`}
            id="confirmation"
            name="confirmation"
            type="checkbox"
            value="verified"
            defaultChecked={state.values.confirmation}
            className="sitaa-checkbox mt-1 h-5 w-5 shrink-0"
            aria-invalid={Boolean(state.fieldErrors.confirmation)}
            aria-describedby={state.fieldErrors.confirmation ? "confirmation-error" : undefined}
          />
          <span>Confirmo que verifiqué la información contra la fuente institucional correspondiente.</span>
        </label>
        <FieldError id="confirmation-error" message={state.fieldErrors.confirmation} />
      </div>

      <div className="flex flex-col-reverse gap-3 pt-2 sm:col-span-2 sm:flex-row sm:items-center sm:justify-end">
        <Link href={`/admin/accounts/${detail.profileId}`} className="sitaa-secondary-action w-full sm:w-auto">Cancelar</Link>
        <SubmitButton />
      </div>
    </form>
  );
}
