"use client";

import Link from "next/link";
import { useActionState, useEffect } from "react";
import { useFormStatus } from "react-dom";
import { registerInstitutionalAccount } from "@/app/register/actions";
import type {
  RegistrationField,
  RegistrationPersonType,
  RegistrationProgram,
  RegistrationState,
} from "@/types/registration";

const emptyState: RegistrationState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  values: {
    full_name: "",
    email: "",
    institutional_id_value: "",
    primary_program_id: "",
  },
};

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="inline-flex min-h-12 cursor-pointer items-center justify-center rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:bg-slate-400 disabled:opacity-70"
    >
      {pending ? "Registrando…" : "Crear cuenta"}
    </button>
  );
}

function fieldClass(error?: string) {
  return `mt-2 w-full min-w-0 rounded-xl border bg-white px-4 py-3 text-slate-900 outline-none transition focus:ring-4 ${
    error
      ? "border-red-400 focus:border-red-600 focus:ring-red-100"
      : "border-slate-300 focus:border-emerald-700 focus:ring-emerald-100"
  }`;
}

function describedBy(field: RegistrationField, help?: boolean) {
  return [help ? `${field}-help` : null, `${field}-error`].filter(Boolean).join(" ");
}

export function RegistrationForm({
  personType,
  programs,
}: {
  personType: RegistrationPersonType;
  programs: RegistrationProgram[];
}) {
  const action = registerInstitutionalAccount.bind(null, personType);
  const [state, formAction] = useActionState(action, emptyState);
  const identifierLabel = personType === "student" ? "Número de cuenta UNAM" : "Número de trabajador UNAM";
  const identifierAutoComplete = personType === "student" ? "off" : "off";
  const firstError = Object.keys(state.fieldErrors)[0] as RegistrationField | undefined;

  useEffect(() => {
    if (state.status === "error" && firstError) {
      document.getElementById(firstError)?.focus();
    }
  }, [firstError, state.status]);

  return (
    <form action={formAction} className="mt-8 grid min-w-0 gap-6 sm:grid-cols-2" noValidate>
      {state.message && (
        <div
          role="alert"
          className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800 sm:col-span-2"
        >
          {state.message}
        </div>
      )}

      <div className="min-w-0 sm:col-span-2">
        <label htmlFor="full_name" className="block text-sm font-semibold text-slate-700">
          Nombre completo
        </label>
        <input
          id="full_name"
          name="full_name"
          autoComplete="name"
          required
          maxLength={200}
          defaultValue={state.values.full_name}
          aria-invalid={Boolean(state.fieldErrors.full_name)}
          aria-describedby={describedBy("full_name")}
          className={fieldClass(state.fieldErrors.full_name)}
        />
        {state.fieldErrors.full_name && (
          <p id="full_name-error" className="mt-2 text-sm text-red-700">
            {state.fieldErrors.full_name}
          </p>
        )}
      </div>

      <div className="min-w-0 sm:col-span-2">
        <label htmlFor="email" className="block text-sm font-semibold text-slate-700">
          Correo electrónico
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          required
          maxLength={254}
          defaultValue={state.values.email}
          aria-invalid={Boolean(state.fieldErrors.email)}
          aria-describedby={describedBy("email", true)}
          className={fieldClass(state.fieldErrors.email)}
        />
        <p id="email-help" className="mt-2 text-xs leading-5 text-slate-500">
          Recibirás un enlace para verificar tu correo y activar el acceso básico.
        </p>
        {state.fieldErrors.email && (
          <p id="email-error" className="mt-2 text-sm text-red-700">
            {state.fieldErrors.email}
          </p>
        )}
      </div>

      <div className="min-w-0">
        <label htmlFor="institutional_id_value" className="block text-sm font-semibold text-slate-700">
          {identifierLabel}
        </label>
        <input
          id="institutional_id_value"
          name="institutional_id_value"
          type="text"
          inputMode="numeric"
          autoComplete={identifierAutoComplete}
          required
          maxLength={50}
          pattern="[0-9]+"
          defaultValue={state.values.institutional_id_value}
          aria-invalid={Boolean(state.fieldErrors.institutional_id_value)}
          aria-describedby={describedBy("institutional_id_value", true)}
          className={fieldClass(state.fieldErrors.institutional_id_value)}
        />
        <p id="institutional_id_value-help" className="mt-2 text-xs leading-5 text-slate-500">
          Escribe sólo dígitos. Los ceros iniciales se conservarán.
        </p>
        {state.fieldErrors.institutional_id_value && (
          <p id="institutional_id_value-error" className="mt-2 text-sm text-red-700">
            {state.fieldErrors.institutional_id_value}
          </p>
        )}
      </div>

      <div className="min-w-0">
        <label htmlFor="primary_program_id" className="block text-sm font-semibold text-slate-700">
          Programa académico principal
        </label>
        <select
          id="primary_program_id"
          name="primary_program_id"
          required
          defaultValue={state.values.primary_program_id}
          aria-invalid={Boolean(state.fieldErrors.primary_program_id)}
          aria-describedby={describedBy("primary_program_id")}
          className={fieldClass(state.fieldErrors.primary_program_id)}
        >
          <option value="" disabled>
            Selecciona un programa
          </option>
          {programs.map((program) => (
            <option key={program.id} value={program.id}>
              {program.name}
            </option>
          ))}
        </select>
        {state.fieldErrors.primary_program_id && (
          <p id="primary_program_id-error" className="mt-2 text-sm text-red-700">
            {state.fieldErrors.primary_program_id}
          </p>
        )}
      </div>

      <div className="min-w-0">
        <label htmlFor="password" className="block text-sm font-semibold text-slate-700">
          Contraseña
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          aria-invalid={Boolean(state.fieldErrors.password)}
          aria-describedby={describedBy("password", true)}
          className={fieldClass(state.fieldErrors.password)}
        />
        <p id="password-help" className="mt-2 text-xs leading-5 text-slate-500">
          Usa al menos 8 caracteres. SITAA nunca almacena tu contraseña en el perfil.
        </p>
        {state.fieldErrors.password && (
          <p id="password-error" className="mt-2 text-sm text-red-700">
            {state.fieldErrors.password}
          </p>
        )}
      </div>

      <div className="min-w-0">
        <label htmlFor="password_confirmation" className="block text-sm font-semibold text-slate-700">
          Confirmar contraseña
        </label>
        <input
          id="password_confirmation"
          name="password_confirmation"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          aria-invalid={Boolean(state.fieldErrors.password_confirmation)}
          aria-describedby={describedBy("password_confirmation")}
          className={fieldClass(state.fieldErrors.password_confirmation)}
        />
        {state.fieldErrors.password_confirmation && (
          <p id="password_confirmation-error" className="mt-2 text-sm text-red-700">
            {state.fieldErrors.password_confirmation}
          </p>
        )}
      </div>

      <div className="flex flex-col gap-3 pt-2 sm:col-span-2 sm:flex-row sm:items-center">
        <SubmitButton />
        <Link
          href="/login"
          className="inline-flex min-h-12 cursor-pointer items-center justify-center rounded-full border border-slate-300 px-7 py-3 text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2"
        >
          Ya tengo cuenta
        </Link>
      </div>
    </form>
  );
}
