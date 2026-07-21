import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert } from "@/components/ui/alert";
import { SectionHeading } from "@/components/ui/section-heading";
import { StatusBadge } from "@/components/ui/status-badge";
import { AdminAccountDataError, getAdminAccountRecord } from "@/lib/admin/accounts";
import {
  AdminIdentityCorrectionDataError,
  getActiveIdentityCorrectionPrograms,
  getAdminIdentityCorrectionContext,
} from "@/lib/admin/identity-correction";
import { IdentityCorrectionForm } from "./identity-correction-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Corrección administrativa de identidad" };

type Props = { params: Promise<{ id: string }> };

const accountKindLabels = {
  institutional: "Institucional",
  technical: "Técnica",
} as const;
const accountStatusLabels = {
  pending_registration: "Registro pendiente",
  active: "Activa",
  inactive: "Inactiva",
} as const;

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

function Definition({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0">
      <dt className="text-sm font-semibold text-slate-500">{label}</dt>
      <dd className="sitaa-wrap-anywhere mt-1 text-[var(--sitaa-text)]">{value}</dd>
    </div>
  );
}

export default async function AdminIdentityCorrectionPage({ params }: Props) {
  const { id } = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
    notFound();
  }

  let record;
  try {
    record = await getAdminAccountRecord(id);
  } catch (error) {
    if (error instanceof AdminAccountDataError && error.kind === "forbidden") redirect("/dashboard");
    if (error instanceof AdminAccountDataError && error.kind === "not_found") notFound();
    return (
      <main className="mx-auto max-w-5xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <Link href={`/admin/accounts/${id}`} className="sitaa-text-action">← Volver al detalle</Link>
        <Alert tone="error" className="mt-6 p-6">No fue posible consultar esta cuenta.</Alert>
      </main>
    );
  }

  let context;
  let programs: Array<{ value: string; label: string }> = [];
  try {
    [context, programs] = await Promise.all([
      getAdminIdentityCorrectionContext(id),
      getActiveIdentityCorrectionPrograms(),
    ]);
  } catch (error) {
    if (error instanceof AdminIdentityCorrectionDataError && error.kind === "forbidden") redirect("/dashboard");
    const pending = error instanceof AdminIdentityCorrectionDataError && error.kind === "migration_pending";
    return (
      <main className="mx-auto max-w-5xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <Link href={`/admin/accounts/${id}`} className="sitaa-text-action">← Volver al detalle</Link>
        <Alert tone={pending ? "warning" : "error"} className="mt-6 p-6">
          <h1 className="text-xl font-bold">{pending ? "Corrección todavía no disponible" : "Corrección no disponible"}</h1>
          <p className="mt-2">{pending ? "La migración 0008 está preparada pero todavía no ha sido aplicada. El detalle de cuenta continúa disponible." : "No fue posible preparar la corrección de identidad. Intenta nuevamente más tarde."}</p>
        </Alert>
      </main>
    );
  }

  if (!context) notFound();
  if (!context.canCorrect) {
    const message = context.isSelf
      ? "No puedes usar esta operación administrativa sobre tu propia cuenta."
      : context.accountStatus === "pending_registration"
        ? "La cuenta debe completar su propio registro antes de cualquier corrección administrativa."
        : "Esta cuenta no es elegible para corrección administrativa de identidad.";
    return (
      <main className="mx-auto max-w-5xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <Link href={`/admin/accounts/${id}`} className="sitaa-text-action">← Volver al detalle</Link>
        <Alert tone="warning" className="mt-6 p-6"><h1 className="text-xl font-bold">Corrección no disponible</h1><p className="mt-2">{message}</p></Alert>
      </main>
    );
  }

  const { detail } = record;
  const dependencyTotal = context.currentOrFutureAssignmentCount
    + context.openResponsibilityCount
    + context.openParticipationCount;

  return (
    <main className="mx-auto max-w-5xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
      <Link href={`/admin/accounts/${id}`} className="sitaa-text-action">← Volver al detalle</Link>
      <SectionHeading
        className="mt-6"
        eyebrow="Administración técnica"
        title="Corrección administrativa de identidad"
        description="Corrige únicamente identidad estable. Esta operación no modifica acceso, estado de cuenta, Auth, roles ni historia operativa."
      />

      <section className="sitaa-detail-card mt-8 p-5 sm:p-7" aria-labelledby="immutable-heading">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <h2 id="immutable-heading" className="text-xl font-bold text-[var(--sitaa-blue-dark)]">Datos inmutables en B.2a</h2>
          <StatusBadge tone={detail.accountStatus === "active" ? "success" : "neutral"}>{accountStatusLabels[detail.accountStatus]}</StatusBadge>
        </div>
        <dl className="mt-5 grid min-w-0 gap-4 sm:grid-cols-2">
          <Definition label="Correo" value={detail.email} />
          <Definition label="Tipo de cuenta" value={accountKindLabels[detail.accountKind]} />
          <Definition label="Estado" value={accountStatusLabels[detail.accountStatus]} />
          <Definition label="Activación" value={formatTimestamp(detail.activatedAt)} />
          <Definition label="Desactivación" value={formatTimestamp(detail.deactivatedAt)} />
          <Definition label="Vínculo de cuenta" value="Se conserva el mismo perfil y usuario Auth" />
        </dl>
      </section>

      {dependencyTotal > 0 ? (
        <Alert tone="warning" className="mt-6 p-5">
          <h2 className="font-bold">Revisa dependencias antes de cambiar tipo o programa</h2>
          <p className="mt-2">La cuenta tiene {context.currentOrFutureAssignmentCount} asignaciones actuales o futuras, {context.openResponsibilityCount} responsabilidades abiertas y {context.openParticipationCount} participaciones abiertas. Los cambios incompatibles serán rechazados sin alterar la cuenta.</p>
        </Alert>
      ) : null}

      <section className="sitaa-card mt-6 p-5 sm:p-7" aria-labelledby="form-heading">
        <h2 id="form-heading" className="text-xl font-bold text-[var(--sitaa-blue-dark)]">Identidad corregida</h2>
        <p className="mt-2 text-[var(--sitaa-text-secondary)]">Los nombres se normalizan conservando Unicode, acentos y apóstrofes. Toda corrección aprobada genera un evento administrativo append-only.</p>
        <IdentityCorrectionForm detail={detail} programs={programs} />
      </section>
    </main>
  );
}
