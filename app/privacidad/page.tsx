import type { Metadata } from "next";
import Link from "next/link";

const description = "Consulta cómo SITAA obtiene, utiliza, protege y conserva datos personales e institucionales.";

export const metadata: Metadata = {
  title: "Aviso de privacidad de SITAA",
  description,
  alternates: { canonical: "https://www.sitaa.net/privacidad" },
  openGraph: {
    title: "Aviso de privacidad de SITAA",
    description,
    url: "https://www.sitaa.net/privacidad",
    siteName: "SITAA",
    locale: "es_MX",
    type: "website",
  },
};

const sectionClass = "border-t border-[var(--sitaa-border)] pt-7";
const headingClass = "sitaa-section-title text-2xl";
const paragraphClass = "mt-3 max-w-3xl leading-7 text-[var(--sitaa-text-secondary)]";
const listClass = "mt-3 max-w-3xl list-disc space-y-2 pl-6 leading-7 text-[var(--sitaa-text-secondary)]";

export default function PrivacyPage() {
  return (
    <main className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-8 sm:py-14">
      <article className="sitaa-surface rounded-3xl p-6 sm:p-10">
        <header>
          <p className="sitaa-section-eyebrow">Información pública</p>
          <h1 className="sitaa-section-title mt-3 text-3xl sm:text-4xl">Aviso de privacidad de SITAA</h1>
          <p className="sitaa-section-description mt-4 max-w-3xl">
            Este aviso explica de forma clara qué datos utiliza SITAA, para qué los necesita y cómo puedes solicitar la revisión de tu información institucional.
          </p>
          <p className="mt-4 text-sm font-semibold text-[var(--sitaa-text-secondary)]">
            Última actualización: <time dateTime="2026-08-07">7 de agosto de 2026</time>.
          </p>
        </header>

        <div className="mt-8 space-y-8">
          <section className={sectionClass} aria-labelledby="responsable-title">
            <h2 id="responsable-title" className={headingClass}>1. Responsable</h2>
            <p className={paragraphClass}>
              La Universidad Nacional Autónoma de México, a través de la Facultad de Estudios Superiores Acatlán, por conducto de la División de Diseño y Edificación, es responsable del tratamiento de los datos personales recabados mediante el Sistema Integral de Tutorías y Asesorías Académicas, SITAA.
            </p>
            <p className={paragraphClass}>Contacto: <a href="mailto:disedif@acatlan.unam.mx" className="sitaa-text-action break-all">disedif@acatlan.unam.mx</a>.</p>
          </section>

          <section className={sectionClass} aria-labelledby="scope-title">
            <h2 id="scope-title" className={headingClass}>2. Alcance del servicio</h2>
            <p className={paragraphClass}>
              SITAA apoya actualmente sólo los programas internos de tutoría y asesoría académica de la División de Diseño y Edificación para Diseño Gráfico y Arquitectura. El servicio está dirigido a personas usuarias adultas.
            </p>
          </section>

          <section className={sectionClass} aria-labelledby="google-data-title">
            <h2 id="google-data-title" className={headingClass}>3. Datos obtenidos de Google</h2>
            <p className={paragraphClass}>SITAA obtiene únicamente:</p>
            <ul className={listClass}>
              <li>la identidad estable de la cuenta de Google usada para vincular la cuenta;</li>
              <li>la dirección de correo electrónico;</li>
              <li>el nombre mostrado;</li>
              <li>la imagen de perfil, cuando Google la proporciona.</li>
            </ul>
            <p className={paragraphClass}>SITAA solicita exclusivamente los scopes <code>openid</code>, <code>userinfo.email</code> y <code>userinfo.profile</code>.</p>
            <p className={paragraphClass}>SITAA no lee ni accede a Gmail, Google Drive, Google Calendar, contactos, documentos, archivos o historial de navegación.</p>
          </section>

          <section className={sectionClass} aria-labelledby="institutional-data-title">
            <h2 id="institutional-data-title" className={headingClass}>4. Datos institucionales</h2>
            <ul className={listClass}>
              <li>nombre o nombres;</li>
              <li>apellido paterno;</li>
              <li>apellido materno, cuando corresponda;</li>
              <li>número de cuenta institucional o número de trabajador;</li>
              <li>tipo de persona;</li>
              <li>programa académico principal;</li>
              <li>clasificación y estado operativo de la cuenta.</li>
            </ul>
          </section>

          <section className={sectionClass} aria-labelledby="academic-data-title">
            <h2 id="academic-data-title" className={headingClass}>5. Datos académicos y operativos</h2>
            <ul className={listClass}>
              <li>actividades académicas de tutoría o asesoría;</li>
              <li>participación registrada;</li>
              <li>asistencia;</li>
              <li>responsabilidades y alcances autorizados;</li>
              <li>fechas y marcas de tiempo necesarias para operación y auditoría;</li>
              <li>eventos administrativos y de seguridad.</li>
            </ul>
          </section>

          <section className={sectionClass} aria-labelledby="purposes-title">
            <h2 id="purposes-title" className={headingClass}>6. Finalidades</h2>
            <p className={paragraphClass}>Las finalidades principales son:</p>
            <ul className={listClass}>
              <li>autenticar a la persona usuaria;</li>
              <li>vincular la identidad de Google con una sola cuenta SITAA;</li>
              <li>completar y validar el perfil institucional;</li>
              <li>administrar el estado y acceso de la cuenta;</li>
              <li>registrar actividades de tutoría y asesoría;</li>
              <li>registrar participantes y asistencia;</li>
              <li>mostrar información según programa, responsabilidad y alcance autorizados;</li>
              <li>generar listas de asistencia y exportaciones operativas autorizadas;</li>
              <li>preservar trazabilidad e historia administrativa;</li>
              <li>prevenir e investigar incidentes técnicos o de seguridad.</li>
            </ul>
            <p className={paragraphClass}>Como finalidad secundaria, SITAA puede generar estadísticas institucionales agregadas y autorizadas para la planeación, seguimiento y evaluación de los programas de tutoría y asesoría.</p>
          </section>

          <section className={sectionClass} aria-labelledby="restrictions-title">
            <h2 id="restrictions-title" className={headingClass}>7. Restricciones de uso</h2>
            <ul className={listClass}>
              <li>los datos no se venden;</li>
              <li>no se utilizan para publicidad;</li>
              <li>no se utilizan para perfiles comerciales;</li>
              <li>no se publican como directorio abierto;</li>
              <li>el acceso se restringe por estado de cuenta, rol, programa, alcance y autorización en la base de datos.</li>
            </ul>
          </section>

          <section className={sectionClass} aria-labelledby="infrastructure-title">
            <h2 id="infrastructure-title" className={headingClass}>8. Infraestructura tecnológica</h2>
            <p className={paragraphClass}>
              SITAA utiliza Supabase para los servicios de autenticación y base de datos, y Vercel para el alojamiento y ejecución de la aplicación web. Estos servicios se utilizan exclusivamente como infraestructura tecnológica para operar y proteger el sistema.
            </p>
          </section>

          <section className={sectionClass} aria-labelledby="cookies-title">
            <h2 id="cookies-title" className={headingClass}>9. Cookies y mecanismos equivalentes</h2>
            <p className={paragraphClass}>
              SITAA utiliza exclusivamente cookies y mecanismos equivalentes necesarios para iniciar, mantener y proteger la sesión, completar el flujo de autenticación y conservar temporalmente la selección del tipo de registro. No utiliza cookies publicitarias ni de seguimiento conductual.
            </p>
          </section>

          <section className={sectionClass} aria-labelledby="retention-title">
            <h2 id="retention-title" className={headingClass}>10. Conservación</h2>
            <p className={paragraphClass}>
              Los datos se conservarán mientras sean necesarios para operar y documentar los programas de tutoría y asesoría académicas, mantener la trazabilidad de actividades y asistencias y atender necesidades administrativas de la División. Cuando dejen de ser necesarios podrán ser depurados o anonimizados. La desactivación de una cuenta no elimina automáticamente los registros históricos ya generados.
            </p>
          </section>

          <section className={sectionClass} aria-labelledby="review-title">
            <h2 id="review-title" className={headingClass}>11. Revisión, corrección y contacto</h2>
            <p className={paragraphClass}>
              Puedes solicitar la revisión o corrección de tu información de identidad institucional mediante <a href="mailto:disedif@acatlan.unam.mx" className="sitaa-text-action break-all">disedif@acatlan.unam.mx</a>. Algunos identificadores, clasificaciones o registros históricos requieren un proceso institucional controlado y no pueden modificarse directamente por la persona usuaria.
            </p>
          </section>

          <section className={sectionClass} aria-labelledby="changes-title">
            <h2 id="changes-title" className={headingClass}>12. Cambios a este aviso</h2>
            <p className={paragraphClass}>
              Este aviso puede actualizarse antes de que SITAA incorpore nuevas categorías de datos o funcionalidades adicionales. La versión vigente se publicará en esta misma ruta.
            </p>
          </section>
        </div>
      </article>

      <nav aria-label="Acciones públicas" className="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-end">
        <Link href="/acerca-de" className="sitaa-secondary-action">Acerca de SITAA</Link>
        <Link href="/login" className="sitaa-secondary-action">Iniciar sesión</Link>
        <Link href="/register" className="sitaa-primary-action">Crear una cuenta</Link>
      </nav>
    </main>
  );
}
