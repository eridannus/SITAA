"use client";

import Link from "next/link";
import { useActionState, useEffect, useState } from "react";
import { useFormStatus } from "react-dom";
import {
  completeGoogleRegistration,
  startGoogleRegistration,
} from "@/app/register/actions";
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
  values: { person_type: "", full_name: "", institutional_id_value: "", primary_program_id: "" },
};

function SubmitButton({ recovery }: { recovery: boolean }) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending}
      className="inline-flex min-h-12 cursor-pointer items-center justify-center rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:bg-slate-400 disabled:opacity-70">
      {pending ? "Continuando…" : recovery ? "Completar registro" : "Continuar con Google"}
    </button>
  );
}

function fieldClass(error?: string) {
  return `mt-2 w-full min-w-0 rounded-xl border bg-white px-4 py-3 text-slate-900 outline-none transition focus:ring-4 ${
    error ? "border-red-400 focus:border-red-600 focus:ring-red-100" : "border-slate-300 focus:border-emerald-700 focus:ring-emerald-100"
  }`;
}

export function RegistrationForm({
  personType,
  programs,
  recovery = false,
}: {
  personType?: RegistrationPersonType;
  programs: RegistrationProgram[];
  recovery?: boolean;
}) {
  const action = recovery ? completeGoogleRegistration : startGoogleRegistration;
  const initialState: RegistrationState = {
    ...emptyState,
    values: { ...emptyState.values, person_type: personType ?? "" },
  };
  const [state, formAction] = useActionState<RegistrationState, FormData>(action, initialState);
  const [selectedType, setSelectedType] = useState<RegistrationPersonType | "">(
    personType ?? state.values.person_type,
  );
  const identifierLabel = selectedType === "professor" ? "Número de trabajador UNAM" : "Número de cuenta UNAM";
  const firstError = Object.keys(state.fieldErrors)[0] as RegistrationField | undefined;

  useEffect(() => {
    if (state.status === "error" && firstError) document.getElementById(firstError)?.focus();
  }, [firstError, state.status]);
  return (
    <form action={formAction} className="mt-8 grid min-w-0 gap-6 sm:grid-cols-2" noValidate>
      {state.message && <div role="alert" className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800 sm:col-span-2">{state.message}</div>}

      {personType ? <input type="hidden" name="person_type" value={personType} /> : (
        <div className="min-w-0 sm:col-span-2">
          <label htmlFor="person_type" className="block text-sm font-semibold text-slate-700">Tipo de registro</label>
          <select id="person_type" name="person_type" required defaultValue={state.values.person_type}
            onChange={(event) => setSelectedType(event.target.value as RegistrationPersonType | "")}
            aria-invalid={Boolean(state.fieldErrors.person_type)} className={fieldClass(state.fieldErrors.person_type)}>
            <option value="" disabled>Selecciona una opción</option>
            <option value="student">Alumno</option>
            <option value="professor">Profesor</option>
          </select>
          {state.fieldErrors.person_type && <p className="mt-2 text-sm text-red-700">{state.fieldErrors.person_type}</p>}
        </div>
      )}

      <div className="min-w-0 sm:col-span-2">
        <label htmlFor="full_name" className="block text-sm font-semibold text-slate-700">Nombre completo</label>
        <input id="full_name" name="full_name" autoComplete="name" required minLength={2} maxLength={200}
          defaultValue={state.values.full_name} aria-invalid={Boolean(state.fieldErrors.full_name)}
          className={fieldClass(state.fieldErrors.full_name)} />
        {state.fieldErrors.full_name && <p className="mt-2 text-sm text-red-700">{state.fieldErrors.full_name}</p>}
      </div>

      <div className="min-w-0">
        <label htmlFor="institutional_id_value" className="block text-sm font-semibold text-slate-700">{identifierLabel}</label>
        <input id="institutional_id_value" name="institutional_id_value" type="text" inputMode="numeric"
          required maxLength={50} pattern="[0-9]+" defaultValue={state.values.institutional_id_value}
          aria-invalid={Boolean(state.fieldErrors.institutional_id_value)} className={fieldClass(state.fieldErrors.institutional_id_value)} />
        <p className="mt-2 text-xs leading-5 text-slate-500">Escribe sólo dígitos. Los ceros iniciales se conservarán.</p>
        {state.fieldErrors.institutional_id_value && <p className="mt-2 text-sm text-red-700">{state.fieldErrors.institutional_id_value}</p>}
      </div>

      <div className="min-w-0">
        <label htmlFor="primary_program_id" className="block text-sm font-semibold text-slate-700">Programa académico principal</label>
        <select id="primary_program_id" name="primary_program_id" required defaultValue={state.values.primary_program_id}
          aria-invalid={Boolean(state.fieldErrors.primary_program_id)} className={fieldClass(state.fieldErrors.primary_program_id)}>
          <option value="" disabled>Selecciona un programa</option>
          {programs.map((program) => <option key={program.id} value={program.id}>{program.name}</option>)}
        </select>
        {state.fieldErrors.primary_program_id && <p className="mt-2 text-sm text-red-700">{state.fieldErrors.primary_program_id}</p>}
      </div>

      {!recovery && <div className="sm:col-span-2 rounded-2xl bg-emerald-50 p-4 text-sm leading-6 text-emerald-950">
        Puedes usar cualquier cuenta de Google. Recomendamos una cuenta personal controlada por ti; una cuenta compartida o de oficina reduce la trazabilidad individual. SITAA solicitará sólo tu identidad básica de Google.
      </div>}

      <div className="flex flex-col gap-3 pt-2 sm:col-span-2 sm:flex-row sm:items-center">
        <SubmitButton recovery={recovery} />
        <Link href={recovery ? "/account-status" : "/login"}
          className="inline-flex min-h-12 cursor-pointer items-center justify-center rounded-full border border-slate-300 px-7 py-3 text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
          {recovery ? "Cancelar" : "Ya tengo cuenta"}
        </Link>
      </div>
    </form>
  );
}
