import type { Metadata } from "next";
import Link from "next/link";
import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Alert } from "@/components/ui/alert";
import { SectionHeading } from "@/components/ui/section-heading";
import {
  AdminAccountLifecycleDataError,
  getAdminAccountLifecycleContext,
} from "@/lib/admin/account-lifecycle";
import { AdminAccountDataError, getAdminAccountRecord } from "@/lib/admin/accounts";
import type { AdminAccountLifecycleTransition } from "@/types/admin";
import { AccountLifecycleForm } from "./account-lifecycle-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Cambiar estado de cuenta" };

type Props = {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ transition?: string | string[] }>;
};

export default async function AccountLifecyclePage({ params, searchParams }: Props) {
  const { id } = await params;
  const query = await searchParams;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) notFound();

  let record;
  let context;
  try {
    [record, context] = await Promise.all([
      getAdminAccountRecord(id),
      getAdminAccountLifecycleContext(id),
    ]);
  } catch (error) {
    if (
      error instanceof AdminAccountDataError && error.kind === "forbidden" ||
      error instanceof AdminAccountLifecycleDataError && error.kind === "forbidden"
    ) redirect("/dashboard");
    if (error instanceof AdminAccountDataError && error.kind === "not_found") notFound();
    const pending = error instanceof AdminAccountLifecycleDataError && error.kind === "migration_pending";
    return (
      <main className="mx-auto max-w-3xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
        <Link href={`/admin/accounts/${id}`} className="sitaa-text-action">← Volver al detalle</Link>
        <Alert tone={pending ? "warning" : "error"} className="mt-6 p-6">
          {pending
            ? "La gestión del estado estará disponible cuando se aplique la migración correspondiente."
            : "No fue posible cargar la operación solicitada."}
        </Alert>
      </main>
    );
  }
  if (!context) notFound();

  const requested = query.transition;
  if (requested !== "deactivate" && requested !== "reactivate") {
    redirect(`/admin/accounts/${id}`);
  }
  const transition: AdminAccountLifecycleTransition = requested;
  const allowed = context.b3aAvailable && context.openOperationId
    ? context.operationCode === transition
    : transition === "deactivate" ? context.canDeactivate : context.canReactivate;
  if (!allowed) redirect(`/admin/accounts/${id}`);

  return (
    <main className="mx-auto max-w-3xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
      <Link href={`/admin/accounts/${id}`} className="sitaa-text-action">← Volver al detalle</Link>
      <div className="sitaa-card mt-6 p-5 sm:p-8">
        <SectionHeading
          eyebrow="Administración técnica"
          title={transition === "deactivate" ? "Desactivar cuenta" : "Reactivar cuenta"}
          description={`${record.detail.fullName || record.detail.email} · ${record.detail.email}`}
        />
        <AccountLifecycleForm
          detail={record.detail}
          context={context}
          transition={transition}
          requestId={randomUUID()}
        />
      </div>
    </main>
  );
}
