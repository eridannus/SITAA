import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { Alert } from "@/components/ui/alert";
import { SectionHeading } from "@/components/ui/section-heading";
import { StatusBadge, type StatusTone } from "@/components/ui/status-badge";
import {
  AdminAccountDataError,
  getAdminAccountFilterOptions,
  searchAdminAccounts,
} from "@/lib/admin/accounts";
import {
  AdminFilterValidationError,
  filtersToSearchParams,
  hasAdminAccountCriteria,
  normalizeAdminAccountFilters,
  type AdminSearchParams,
} from "@/lib/admin/filters";
import type { AdminAccountFilters, AdminAccountSearchResult } from "@/types/admin";
import type { AccountStatus } from "@/types/sitaa";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Administración de cuentas" };

type Props = { searchParams: Promise<AdminSearchParams> };

const accountKindLabels = { institutional: "Institucional", technical: "Técnica" } as const;
const accountStatusLabels = {
  pending_registration: "Registro pendiente",
  active: "Activa",
  inactive: "Inactiva",
} as const;
const personTypeLabels = { student: "Alumno", professor: "Profesor" } as const;
const identifierLabels = {
  student_account: "Número de cuenta",
  worker_number: "Número de trabajador",
} as const;

function accountStatusTone(status: AccountStatus): StatusTone {
  if (status === "active") return "success";
  if (status === "pending_registration") return "warning";
  return "neutral";
}

function displayName(item: AdminAccountSearchResult["accounts"][number]) {
  return item.fullName?.trim() || item.email;
}

function ModuleState({ kind }: { kind: "migration_pending" | "unavailable" }) {
  return (
    <Alert tone={kind === "migration_pending" ? "warning" : "error"} className="mt-8 p-6">
      <h2 className="text-lg font-bold">
        {kind === "migration_pending" ? "Módulo todavía no disponible" : "Directorio no disponible"}
      </h2>
      <p className="mt-2">
        {kind === "migration_pending"
          ? "La migración 0007 está pendiente de aplicación coordinada. El resto de SITAA continúa disponible."
          : "No fue posible consultar el directorio de cuentas. Intenta nuevamente más tarde."}
      </p>
    </Alert>
  );
}

export default async function AdminAccountsPage({ searchParams }: Props) {
  const params = await searchParams;
  let filters: AdminAccountFilters | null = null;
  let validationMessage: string | null = null;
  try {
    filters = normalizeAdminAccountFilters(params);
  } catch (error) {
    validationMessage = error instanceof AdminFilterValidationError
      ? error.message
      : "Los filtros no son válidos.";
  }

  let options = { programs: [] as Array<{ value: string; label: string }>, roles: [] as Array<{ value: string; label: string }> };
  try {
    options = await getAdminAccountFilterOptions();
  } catch {
    // Los filtros de catálogos pueden quedar vacíos sin exponer errores internos.
  }

  let result: AdminAccountSearchResult | null = null;
  let dataState: "migration_pending" | "unavailable" | null = null;
  if (filters && !validationMessage) {
    try {
      result = await searchAdminAccounts(filters);
    } catch (error) {
      if (error instanceof AdminAccountDataError && error.kind === "forbidden") redirect("/dashboard");
      dataState = error instanceof AdminAccountDataError && error.kind === "migration_pending"
        ? "migration_pending"
        : "unavailable";
    }
  }

  const hasCriteria = filters ? hasAdminAccountCriteria(filters) : false;
  const pages = result ? Math.max(1, Math.ceil(result.total / result.pageSize)) : 1;

  return (
    <main className="mx-auto max-w-7xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
      <SectionHeading
        eyebrow="Administración técnica"
        title="Cuentas"
        description="Consulta cuentas registradas y sus asignaciones vigentes. Este módulo es exclusivamente de lectura."
      />

      <form method="get" className="sitaa-card mt-8 grid gap-5 p-5 sm:p-7 lg:grid-cols-4" aria-label="Filtros del directorio">
        <label className="lg:col-span-2">
          <span className="sitaa-form-label">Buscar cuenta</span>
          <input name="q" defaultValue={filters?.query ?? ""} className="sitaa-field mt-2" minLength={2} maxLength={200} placeholder="Nombre, correo o identificador" />
        </label>
        <label>
          <span className="sitaa-form-label">Programa académico</span>
          <select name="program" defaultValue={filters?.programId ?? ""} className="sitaa-field mt-2">
            <option value="">Todos</option>
            {options.programs.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
          </select>
        </label>
        <label>
          <span className="sitaa-form-label">Tipo de cuenta</span>
          <select name="kind" defaultValue={filters?.accountKind ?? ""} className="sitaa-field mt-2">
            <option value="">Todos</option><option value="institutional">Institucional</option><option value="technical">Técnica</option>
          </select>
        </label>
        <label>
          <span className="sitaa-form-label">Estado</span>
          <select name="status" defaultValue={filters?.accountStatus ?? ""} className="sitaa-field mt-2">
            <option value="">Todos</option><option value="pending_registration">Registro pendiente</option><option value="active">Activa</option><option value="inactive">Inactiva</option>
          </select>
        </label>
        <label>
          <span className="sitaa-form-label">Tipo de persona</span>
          <select name="person" defaultValue={filters?.personType ?? ""} className="sitaa-field mt-2">
            <option value="">Todos</option><option value="student">Alumno</option><option value="professor">Profesor</option>
          </select>
        </label>
        <label>
          <span className="sitaa-form-label">Rol actual</span>
          <select name="role" defaultValue={filters?.roleCode ?? ""} className="sitaa-field mt-2">
            <option value="">Todos</option>
            {options.roles.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
          </select>
        </label>
        <label>
          <span className="sitaa-form-label">Área de servicio</span>
          <select name="service" defaultValue={filters?.serviceArea ?? ""} className="sitaa-field mt-2">
            <option value="">Todas</option><option value="tutoring">Tutorías</option><option value="advising">Asesorías</option><option value="both">Ambas</option><option value="logistics">Logística</option><option value="technical">Técnica</option>
          </select>
        </label>
        <label>
          <span className="sitaa-form-label">Alcance</span>
          <select name="scope" defaultValue={filters?.scopeType ?? ""} className="sitaa-field mt-2">
            <option value="">Todos</option><option value="own">Propio</option><option value="program">Programa</option><option value="division">División</option><option value="system">Sistema</option>
          </select>
        </label>
        <label>
          <span className="sitaa-form-label">Resultados por página</span>
          <select name="size" defaultValue={String(filters?.pageSize ?? 20)} className="sitaa-field mt-2">
            <option value="20">20</option><option value="50">50</option>
          </select>
        </label>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end lg:col-span-4">
          <button type="submit" className="sitaa-primary-action">Buscar</button>
          <Link href="/admin/accounts" className="sitaa-secondary-action">Limpiar filtros</Link>
        </div>
      </form>

      {validationMessage ? <Alert tone="warning" className="mt-6" role="alert">{validationMessage}</Alert> : null}
      {dataState ? <ModuleState kind={dataState} /> : null}

      {!dataState && !validationMessage && !hasCriteria ? (
        <div className="sitaa-empty-state mt-8 text-center">
          <h2 className="text-lg font-bold">Define una búsqueda o un filtro</h2>
          <p className="mt-2">Por privacidad, SITAA no muestra el directorio completo de forma predeterminada.</p>
        </div>
      ) : null}

      {!dataState && result && hasCriteria && result.accounts.length === 0 ? (
        <div className="sitaa-empty-state mt-8 text-center">
          <h2 className="text-lg font-bold">No se encontraron cuentas</h2>
          <p className="mt-2">Ajusta los criterios e intenta nuevamente.</p>
        </div>
      ) : null}

      {result && result.accounts.length > 0 ? (
        <section className="mt-8" aria-labelledby="account-results">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <h2 id="account-results" className="text-xl font-bold text-[var(--sitaa-blue-dark)]">Resultados</h2>
            <p className="text-sm text-[var(--sitaa-text-secondary)]">{result.total} {result.total === 1 ? "cuenta" : "cuentas"}</p>
          </div>
          <ul className="mt-4 grid gap-4">
            {result.accounts.map((item) => (
              <li key={item.profileId} className="sitaa-card min-w-0 p-5 sm:p-6">
                <div className="flex min-w-0 flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="sitaa-wrap-anywhere text-lg font-bold text-[var(--sitaa-blue-dark)]">{displayName(item)}</h3>
                      <StatusBadge tone={accountStatusTone(item.accountStatus)}>{accountStatusLabels[item.accountStatus]}</StatusBadge>
                    </div>
                    <p className="sitaa-wrap-anywhere mt-2 text-sm text-[var(--sitaa-text-secondary)]">{item.email}</p>
                    <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2 lg:grid-cols-4">
                      <div><dt className="font-semibold text-slate-500">Cuenta</dt><dd>{accountKindLabels[item.accountKind]}</dd></div>
                      <div><dt className="font-semibold text-slate-500">Persona</dt><dd>{item.personType ? personTypeLabels[item.personType] : "No aplica"}</dd></div>
                      <div><dt className="font-semibold text-slate-500">Programa</dt><dd className="break-words">{item.primaryProgramName ?? "No aplica"}</dd></div>
                      <div><dt className="font-semibold text-slate-500">Filas con vigencia actual</dt><dd>{item.currentAssignmentCount}</dd></div>
                      {item.institutionalIdType && item.maskedInstitutionalId ? <div className="sm:col-span-2"><dt className="font-semibold text-slate-500">{identifierLabels[item.institutionalIdType]}</dt><dd className="break-words">{item.maskedInstitutionalId}</dd></div> : null}
                    </dl>
                  </div>
                  <Link href={`/admin/accounts/${item.profileId}`} className="sitaa-secondary-action shrink-0">Ver detalle</Link>
                </div>
              </li>
            ))}
          </ul>
          <nav aria-label="Paginación del directorio" className="mt-6 flex flex-wrap items-center justify-between gap-3">
            {result.page > 1 ? <Link className="sitaa-secondary-action" href={`/admin/accounts?${filtersToSearchParams(filters!, result.page - 1)}`}>Anterior</Link> : <span />}
            <span className="text-sm font-semibold text-[var(--sitaa-text-secondary)]">Página {result.page} de {pages}</span>
            {result.page < pages ? <Link className="sitaa-secondary-action" href={`/admin/accounts?${filtersToSearchParams(filters!, result.page + 1)}`}>Siguiente</Link> : <span />}
          </nav>
        </section>
      ) : null}
    </main>
  );
}
