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
      className="sitaa-primary-action w-full sm:w-auto"
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
