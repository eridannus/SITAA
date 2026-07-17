"use client";

import { useFormStatus } from "react-dom";
import { startGoogleRegistration } from "@/app/register/actions";
import type { RegistrationPersonType } from "@/types/registration";

function GoogleButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="inline-flex min-h-12 w-full cursor-pointer items-center justify-center rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:bg-slate-400 disabled:opacity-70 sm:w-auto"
    >
      {pending ? "Continuando…" : "Continuar con Google"}
    </button>
  );
}

export function GoogleRegistrationStart({ personType }: { personType: RegistrationPersonType }) {
  return (
    <form action={startGoogleRegistration} className="mt-8">
      <input type="hidden" name="registration_type" value={personType} />
      <GoogleButton />
    </form>
  );
}
