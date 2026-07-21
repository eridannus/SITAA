import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert } from "@/components/ui/alert";
import { SectionHeading } from "@/components/ui/section-heading";
import { StatusBadge, type StatusTone } from "@/components/ui/status-badge";
import { AdminAccountDataError, getAdminAccountRecord } from "@/lib/admin/accounts";
import {
  AdminIdentityCorrectionDataError,
  getAdminIdentityCorrectionContext,
} from "@/lib/admin/identity-correction";
import type { AssignmentPresentationStatus } from "@/types/admin";
import type { AccountStatus, AssignmentScope, InstitutionalIdType, PersonType, ServiceArea } from "@/types/sitaa";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Detalle de cuenta" };

type Props = {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ identity?: string | string[] }>;
};

const accountKindLabels = { institutional: "Institucional", technical: "Técnica" } as const;
const accountStatusLabels = { pending_registration: "Registro pendiente", active: "Activa", inactive: "Inactiva" } as const;
const personTypeLabels: Record<PersonType, string> = { student: "Alumno", professor: "Profesor" };
const identifierLabels: Record<InstitutionalIdType, string> = { student_account: "Número de cuenta", worker_number: "Número de trabajador" };
const scopeLabels: Record<AssignmentScope, string> = { own: "Propio", program: "Programa", division: "División", system: "Sistema" };
const serviceLabels: Record<ServiceArea, string> = { tutoring: "Tutorías", advising: "Asesorías", both: "Tutorías y asesorías", logistics: "Logística", technical: "Técnica" };
const assignmentLabels: Record<AssignmentPresentationStatus, string> = {
  current: "Actual",
  future: "Futura",
  expired: "Vencida",
  inactive: "Inactiva",
  suspended_by_account_status: "Suspendida por estado de cuenta",
};
const auditActionLabels: Record<string, string> = {
  account_identity_corrected: "Identidad corregida",
};

function accountTone(status: AccountStatus): StatusTone {
  return status === "active" ? "success" : status === "pending_registration" ? "warning" : "neutral";
}

function assignmentTone(status: AssignmentPresentationStatus): StatusTone {
  if (status === "current") return "success";
  if (status === "future") return "info";
  if (status === "suspended_by_account_status") return "warning";
  return "neutral";
}

function formatDate(value: string | null) {
  if (!value) return "No aplica";
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function formatTimestamp(value: string | null) {
  if (!value) return "No aplica";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "No disponible";
  return new Intl.DateTimeFormat("es-MX", {
    timeZone: "America/Mexico_City",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

function Definition({ label, value }: { label: string; value: string | null }) {
  return <div className="min-w-0"><dt className="text-sm font-semibold text-slate-500">{label}</dt><dd className="sitaa-wrap-anywhere mt-1 text-[var(--sitaa-text)]">{value || "No aplica"}</dd></div>;
}

export default async function AdminAccountDetailPage({ params, searchParams }: Props) {
  const { id } = await params;
  const query = await searchParams;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) notFound();

  let record;
  try {
    record = await getAdminAccountRecord(id);
  } catch (error) {
    if (error instanceof AdminAccountDataError && error.kind === "forbidden") redirect("/dashboard");
    if (error instanceof AdminAccountDataError && error.kind === "not_found") notFound();
    const pending = error instanceof AdminAccountDataError && error.kind === "migration_pending";
    return (
      <main className="mx-auto max-w-5xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <Link href="/admin/accounts" className="sitaa-text-action">← Volver a cuentas</Link>
        <Alert tone={pending ? "warning" : "error"} className="mt-6 p-6">
          <h1 className="text-xl font-bold">{pending ? "Módulo todavía no disponible" : "Detalle no disponible"}</h1>
          <p className="mt-2">{pending ? "La migración 0007 está pendiente de aplicación coordinada." : "No fue posible consultar esta cuenta. Intenta nuevamente más tarde."}</p>
        </Alert>
      </main>
    );
  }

  let correctionContext = null;
  try {
    correctionContext = await getAdminIdentityCorrectionContext(id);
  } catch (error) {
    if (error instanceof AdminIdentityCorrectionDataError && error.kind === "forbidden") {
      redirect("/dashboard");
    }
    // Antes de aplicar 0008, B.1 permanece plenamente operativo y de sólo lectura.
  }

  const { detail, assignments, auditHistory } = record;
  const identityCorrected = query.identity === "corrected";
  return (
    <main className="mx-auto max-w-6xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
      <Link href="/admin/accounts" className="sitaa-text-action">← Volver a cuentas</Link>
      <div className="mt-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <SectionHeading eyebrow="Administración técnica" title={detail.fullName || detail.email} description="Consulta autorizada de identidad, asignaciones e historial administrativo." />
        <div className="flex flex-col items-start gap-3 sm:items-end">
          <StatusBadge tone={accountTone(detail.accountStatus)} className="w-fit">{accountStatusLabels[detail.accountStatus]}</StatusBadge>
          {correctionContext?.canCorrect ? (
            <Link href={`/admin/accounts/${id}/identity`} className="sitaa-primary-action">Corregir identidad</Link>
          ) : null}
        </div>
      </div>

      {identityCorrected ? (
        <Alert tone="success" className="mt-6 p-5">La identidad se corrigió correctamente y el evento administrativo quedó registrado.</Alert>
      ) : null}

      <section className="sitaa-card mt-8 p-5 sm:p-7" aria-labelledby="identity-heading">
        <h2 id="identity-heading" className="text-xl font-bold text-[var(--sitaa-blue-dark)]">Identidad y cuenta</h2>
        <dl className="mt-6 grid min-w-0 gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <Definition label="Nombres" value={detail.firstNames} />
          <Definition label="Apellido paterno" value={detail.paternalSurname} />
          <Definition label="Apellido materno" value={detail.maternalSurname} />
          <Definition label="Nombre derivado" value={detail.fullName} />
          <Definition label="Correo" value={detail.email} />
          <Definition label="Tipo de cuenta" value={accountKindLabels[detail.accountKind]} />
          <Definition label="Tipo de persona" value={detail.personType ? personTypeLabels[detail.personType] : null} />
          <Definition label="Programa principal" value={detail.primaryProgramName} />
          <Definition label={detail.institutionalIdType ? identifierLabels[detail.institutionalIdType] : "Identificador institucional"} value={detail.institutionalIdValue} />
          <Definition label="Correo de acceso confirmado" value={detail.authEmailConfirmed ? "Sí" : "No"} />
          <Definition label="Activación" value={formatTimestamp(detail.activatedAt)} />
          <Definition label="Desactivación" value={formatTimestamp(detail.deactivatedAt)} />
        </dl>
      </section>

      <section className="mt-8" aria-labelledby="assignments-heading">
        <h2 id="assignments-heading" className="text-xl font-bold text-[var(--sitaa-blue-dark)]">Historial de asignaciones V1</h2>
        {assignments.length === 0 ? <div className="sitaa-empty-state mt-4">Esta cuenta no tiene asignaciones de rol.</div> : (
          <div className="mt-4 grid gap-4 lg:grid-cols-2">
            {assignments.map((assignment) => (
              <article key={assignment.id} className="sitaa-card min-w-0 p-5">
                <div className="flex flex-wrap items-start justify-between gap-3"><h3 className="font-bold text-[var(--sitaa-text)]">{assignment.roleLabel}</h3><StatusBadge tone={assignmentTone(assignment.presentationStatus)}>{assignmentLabels[assignment.presentationStatus]}</StatusBadge></div>
                <dl className="mt-5 grid gap-4 sm:grid-cols-2">
                  <Definition label="Código" value={assignment.roleCode} />
                  <Definition label="Área" value={serviceLabels[assignment.serviceArea]} />
                  <Definition label="Alcance" value={scopeLabels[assignment.scopeType]} />
                  <Definition label="Programa" value={assignment.programName} />
                  <Definition label="División" value={assignment.divisionName} />
                  <Definition label="Inicio" value={formatDate(assignment.startsAt)} />
                  <Definition label="Término" value={formatDate(assignment.endsAt)} />
                  <Definition label="Bandera activa" value={assignment.isActive ? "Sí" : "No"} />
                </dl>
              </article>
            ))}
          </div>
        )}
      </section>

      <section className="mt-8" aria-labelledby="audit-heading">
        <h2 id="audit-heading" className="text-xl font-bold text-[var(--sitaa-blue-dark)]">Historial administrativo sanitizado</h2>
        {auditHistory.length === 0 ? <div className="sitaa-empty-state mt-4">No hay eventos administrativos registrados para esta cuenta.</div> : (
          <ol className="mt-4 grid gap-4">
            {auditHistory.map((event) => (
              <li key={event.id} className="sitaa-card min-w-0 p-5">
                <div className="flex flex-wrap items-center justify-between gap-3"><p className="sitaa-wrap-anywhere font-bold">{auditActionLabels[event.actionCode] ?? event.actionCode}</p><StatusBadge tone={event.outcome === "success" ? "success" : "error"}>{event.outcome === "success" ? "Correcto" : "Fallido"}</StatusBadge></div>
                <dl className="mt-4 grid gap-4 sm:grid-cols-2">
                  <Definition label="Fecha" value={formatTimestamp(event.occurredAt)} />
                  <Definition label="Actor" value={event.actorDisplayName || "Cuenta administrativa"} />
                  {event.reason ? <Definition label="Motivo" value={event.reason} /> : null}
                </dl>
              </li>
            ))}
          </ol>
        )}
      </section>
    </main>
  );
}
