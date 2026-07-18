"use client";

import { useActionState, useEffect } from "react";
import { useFormStatus } from "react-dom";
import { completeGoogleRegistration } from "@/app/register/actions";
import type {
  RegistrationField,
  RegistrationPersonType,
  RegistrationProgram,
  RegistrationState,
} from "@/types/registration";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="sitaa-primary-action"
    >
      {pending ? "Completando…" : "Completar registro"}
    </button>
  );
}

function fieldClass(error?: string) {
  return `sitaa-field mt-2 ${error ? "sitaa-field-invalid" : ""}`;
}

export function RegistrationForm({
  personType,
  programs,
}: {
  personType: RegistrationPersonType;
  programs: RegistrationProgram[];
}) {
  const initialState: RegistrationState = {
    status: "idle",
    message: null,
    fieldErrors: {},
    values: {
      person_type: personType,
      first_names: "",
      paternal_surname: "",
      maternal_surname: "",
      institutional_id_value: "",
      primary_program_id: "",
    },
  };
  const [state, formAction] = useActionState<RegistrationState, FormData>(
    completeGoogleRegistration,
    initialState,
  );
  const identifierLabel = personType === "professor"
    ? "Número de trabajador UNAM"
    : "Número de cuenta UNAM";
  const firstError = Object.keys(state.fieldErrors)[0] as RegistrationField | undefined;

  useEffect(() => {
    if (state.status === "error" && firstError) document.getElementById(firstError)?.focus();
  }, [firstError, state.status]);

  return (
    <form action={formAction} className="mt-8 grid min-w-0 gap-6 sm:grid-cols-2" noValidate>
      <input type="hidden" name="person_type" value={personType} />

      {state.message && (
        <div role="alert" className="sitaa-alert sitaa-alert--error sm:col-span-2">
          {state.message}
        </div>
      )}

      <div className="min-w-0 sm:col-span-2">
        <label htmlFor="first_names" className="sitaa-form-label">
          Nombre(s)
        </label>
        <input
          key={`first-names-${state.values.first_names}`}
          id="first_names"
          name="first_names"
          autoComplete="given-name"
          required
          maxLength={150}
          defaultValue={state.values.first_names}
          aria-invalid={Boolean(state.fieldErrors.first_names)}
          aria-describedby={state.fieldErrors.first_names ? "first_names-error" : undefined}
          className={fieldClass(state.fieldErrors.first_names)}
        />
        {state.fieldErrors.first_names && <p id="first_names-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">{state.fieldErrors.first_names}</p>}
      </div>

      <div className="min-w-0">
        <label htmlFor="paternal_surname" className="sitaa-form-label">Apellido paterno</label>
        <input key={`paternal-${state.values.paternal_surname}`} id="paternal_surname" name="paternal_surname" autoComplete="family-name" required maxLength={150} defaultValue={state.values.paternal_surname} aria-invalid={Boolean(state.fieldErrors.paternal_surname)} aria-describedby={state.fieldErrors.paternal_surname ? "paternal_surname-error" : undefined} className={fieldClass(state.fieldErrors.paternal_surname)} />
        {state.fieldErrors.paternal_surname && <p id="paternal_surname-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">{state.fieldErrors.paternal_surname}</p>}
      </div>

      <div className="min-w-0">
        <label htmlFor="maternal_surname" className="sitaa-form-label">Apellido materno <span className="font-normal text-[var(--sitaa-text-secondary)]">(opcional)</span></label>
        <input key={`maternal-${state.values.maternal_surname}`} id="maternal_surname" name="maternal_surname" autoComplete="additional-name" maxLength={150} defaultValue={state.values.maternal_surname} aria-invalid={Boolean(state.fieldErrors.maternal_surname)} aria-describedby={state.fieldErrors.maternal_surname ? "maternal_surname-error" : "maternal_surname-help"} className={fieldClass(state.fieldErrors.maternal_surname)} />
        <p id="maternal_surname-help" className="sitaa-help-text mt-2">Déjalo vacío si no cuentas con apellido materno.</p>
        {state.fieldErrors.maternal_surname && <p id="maternal_surname-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">{state.fieldErrors.maternal_surname}</p>}
      </div>

      <div className="min-w-0">
        <label htmlFor="institutional_id_value" className="sitaa-form-label">
          {identifierLabel}
        </label>
        <input
          key={`identifier-${state.values.institutional_id_value}`}
          id="institutional_id_value"
          name="institutional_id_value"
          type="text"
          inputMode="numeric"
          required
          maxLength={50}
          pattern="[0-9]+"
          defaultValue={state.values.institutional_id_value}
          aria-invalid={Boolean(state.fieldErrors.institutional_id_value)}
          aria-describedby={state.fieldErrors.institutional_id_value
            ? "institutional-id-help institutional-id-error"
            : "institutional-id-help"}
          className={fieldClass(state.fieldErrors.institutional_id_value)}
        />
        <p id="institutional-id-help" className="sitaa-help-text mt-2">
          Escribe sólo dígitos. Los ceros iniciales se conservarán.
        </p>
        {state.fieldErrors.institutional_id_value && <p id="institutional-id-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">{state.fieldErrors.institutional_id_value}</p>}
      </div>

      <div className="min-w-0">
        <label htmlFor="primary_program_id" className="sitaa-form-label">
          Programa académico principal
        </label>
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
          <option value="" disabled>Selecciona un programa</option>
          {programs.map((program) => <option key={program.id} value={program.id}>{program.name}</option>)}
        </select>
        {state.fieldErrors.primary_program_id && <p id="primary_program_id-error" className="mt-2 text-sm text-[var(--sitaa-error-foreground)]">{state.fieldErrors.primary_program_id}</p>}
      </div>

      <div className="flex flex-col gap-3 pt-2 sm:col-span-2 sm:flex-row sm:items-center">
        <SubmitButton />
      </div>
    </form>
  );
}
