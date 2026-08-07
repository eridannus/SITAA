import type { Metadata } from "next";
import Link from "next/link";
import { PublicPolicyLinks } from "@/components/public-policy-links";

const description = "Conoce el propósito, alcance académico y uso de Google como proveedor de identidad de SITAA.";

export const metadata: Metadata = {
  title: "Acerca de SITAA",
  description,
  alternates: { canonical: "https://www.sitaa.net/acerca-de" },
  openGraph: {
    title: "Acerca de SITAA",
    description,
    url: "https://www.sitaa.net/acerca-de",
    siteName: "SITAA",
    locale: "es_MX",
    type: "website",
  },
};

const contacts = [
  { label: "División de Diseño y Edificación", email: "disedif@acatlan.unam.mx" },
  { label: "Programa de Diseño Gráfico", email: "disenogr@acatlan.unam.mx" },
  { label: "Programa de Arquitectura", email: "arquitec@acatlan.unam.mx" },
];

export default function AboutSitaaPage() {
  return (
    <main className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-8 sm:py-14">
      <header className="sitaa-surface rounded-3xl p-6 sm:p-10">
        <p className="sitaa-section-eyebrow">Información institucional</p>
        <h1 className="sitaa-section-title mt-3 text-3xl sm:text-4xl">Acerca de SITAA</h1>
        <p className="sitaa-section-description mt-4 max-w-3xl">
          SITAA significa Sistema Integral de Tutorías y Asesorías Académicas. Es operado por la División de Diseño y Edificación de la Facultad de Estudios Superiores Acatlán para apoyar sus programas internos de tutoría y asesoría académica.
        </p>
        <PublicPolicyLinks className="mt-5 border-t border-[var(--sitaa-border)] pt-3" />
      </header>

      <div className="mt-8 grid gap-6 lg:grid-cols-2">
        <section className="sitaa-card p-6 sm:p-8" aria-labelledby="scope-title">
          <p className="sitaa-section-eyebrow">Alcance actual</p>
          <h2 id="scope-title" className="sitaa-section-title mt-2 text-2xl">Tutorías y asesorías de la División</h2>
          <p className="sitaa-section-description mt-4">
            El alcance presente se limita a los programas académicos internos de Diseño Gráfico y Arquitectura. El sistema está dirigido a estudiantes adultos y a personal institucional adulto.
          </p>
          <p className="sitaa-section-description mt-4">
            SITAA busca reemplazar listas de asistencia en papel, formularios de registro aislados y hojas de cálculo de asistencia mantenidas manualmente. Actualmente registra actividades, participantes registrados y asistencia.
          </p>
        </section>

        <section className="sitaa-card p-6 sm:p-8" aria-labelledby="identity-title">
          <p className="sitaa-section-eyebrow">Identidad y acceso</p>
          <h2 id="identity-title" className="sitaa-section-title mt-2 text-2xl">Google inicia la autenticación</h2>
          <p className="sitaa-section-description mt-4">
            Google se utiliza únicamente como proveedor inicial de identidad. Después de autenticarte, completas dentro de SITAA la información institucional necesaria para tu cuenta.
          </p>
          <p className="sitaa-section-description mt-4">
            SITAA no solicita acceso a Gmail, Google Drive, Google Calendar, contactos ni archivos de Google. El acceso final depende del estado de la cuenta SITAA y de las responsabilidades institucionales autorizadas.
          </p>
        </section>
      </div>

      <section className="sitaa-surface mt-8 rounded-3xl p-6 sm:p-9" aria-labelledby="contact-title">
        <p className="sitaa-section-eyebrow">Contacto institucional</p>
        <h2 id="contact-title" className="sitaa-section-title mt-2 text-2xl">¿Necesitas orientación?</h2>
        <ul className="mt-5 grid gap-4 md:grid-cols-3">
          {contacts.map((contact) => (
            <li key={contact.email} className="sitaa-detail-card min-w-0 p-4">
              <p className="font-bold text-[var(--sitaa-text)]">{contact.label}</p>
              <a href={`mailto:${contact.email}`} className="sitaa-text-action mt-2 inline-block break-all">
                {contact.email}
              </a>
            </li>
          ))}
        </ul>
      </section>

      <nav aria-label="Acciones públicas" className="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-end">
        <Link href="/privacidad" className="sitaa-secondary-action">Leer el aviso de privacidad</Link>
        <Link href="/login" className="sitaa-secondary-action">Iniciar sesión</Link>
        <Link href="/register" className="sitaa-primary-action">Crear una cuenta</Link>
      </nav>
    </main>
  );
}
