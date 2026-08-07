import Link from "next/link";

type PublicPolicyLinksProps = {
  className?: string;
  showRegistrationNotice?: boolean;
};

export function PublicPolicyLinks({ className = "", showRegistrationNotice = false }: PublicPolicyLinksProps) {
  return (
    <div className={className}>
      {showRegistrationNotice && (
        <p className="mb-2 text-center text-sm leading-6 text-[var(--sitaa-text-secondary)]">
          Consulta el Aviso de privacidad de SITAA para conocer el tratamiento de tus datos institucionales.
        </p>
      )}
      <nav aria-label="Información pública de SITAA" className="flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-sm text-[var(--sitaa-text-secondary)]">
        <Link href="/acerca-de" className="inline-flex min-h-11 cursor-pointer items-center rounded-lg px-2 font-semibold hover:bg-[var(--sitaa-blue-light)] hover:text-[var(--sitaa-blue-dark)]">
          Acerca de SITAA
        </Link>
        <span aria-hidden="true">·</span>
        <Link href="/privacidad" className="inline-flex min-h-11 cursor-pointer items-center rounded-lg px-2 font-semibold hover:bg-[var(--sitaa-blue-light)] hover:text-[var(--sitaa-blue-dark)]">
          Aviso de privacidad
        </Link>
      </nav>
    </div>
  );
}
