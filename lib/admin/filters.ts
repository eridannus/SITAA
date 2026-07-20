import type { AdminAccountFilters } from "@/types/admin";
import type {
  AccountKind,
  AccountStatus,
  AssignmentScope,
  PersonType,
  ServiceArea,
} from "@/types/sitaa";

type SearchValue = string | string[] | undefined;
export type AdminSearchParams = Record<string, SearchValue>;

const accountKinds = new Set<AccountKind>(["institutional", "technical"]);
const accountStatuses = new Set<AccountStatus>([
  "pending_registration",
  "active",
  "inactive",
]);
const personTypes = new Set<PersonType>(["student", "professor"]);
const serviceAreas = new Set<ServiceArea>([
  "tutoring",
  "advising",
  "both",
  "logistics",
  "technical",
]);
const scopeTypes = new Set<AssignmentScope>([
  "own",
  "program",
  "division",
  "system",
]);

function first(value: SearchValue) {
  return (Array.isArray(value) ? value[0] : value)?.trim() ?? "";
}

function enumValue<T extends string>(
  value: string,
  allowed: Set<T>,
  field: string,
) {
  if (!value) return "";
  if (!allowed.has(value as T)) {
    throw new AdminFilterValidationError(`El filtro ${field} no es válido.`);
  }
  return value as T;
}

function positiveInteger(value: string, fallback: number, maximum: number) {
  if (!value) return fallback;
  if (!/^\d+$/.test(value)) throw new AdminFilterValidationError("La paginación no es válida.");
  const number = Number(value);
  if (number < 1 || number > maximum) {
    throw new AdminFilterValidationError("La paginación está fuera de los límites permitidos.");
  }
  return number;
}

export class AdminFilterValidationError extends Error {}

export function normalizeAdminAccountFilters(
  params: AdminSearchParams,
): AdminAccountFilters {
  const query = first(params.q).replace(/\s+/g, " ");
  if (query.length === 1 || query.length > 200) {
    throw new AdminFilterValidationError(
      "La búsqueda debe tener entre 2 y 200 caracteres.",
    );
  }

  const programId = first(params.program);
  if (programId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(programId)) {
    throw new AdminFilterValidationError("El programa seleccionado no es válido.");
  }
  const roleCode = first(params.role);
  if (roleCode && !/^[a-z][a-z0-9_]{0,99}$/.test(roleCode)) {
    throw new AdminFilterValidationError("El rol seleccionado no es válido.");
  }

  return {
    query,
    programId,
    accountKind: enumValue(first(params.kind), accountKinds, "de tipo de cuenta"),
    accountStatus: enumValue(first(params.status), accountStatuses, "de estado"),
    personType: enumValue(first(params.person), personTypes, "de tipo de persona"),
    roleCode,
    serviceArea: enumValue(first(params.service), serviceAreas, "de área de servicio"),
    scopeType: enumValue(first(params.scope), scopeTypes, "de alcance"),
    page: positiveInteger(first(params.page), 1, 1_000_000),
    pageSize: positiveInteger(first(params.size), 20, 50),
  };
}

export function hasAdminAccountCriteria(filters: AdminAccountFilters) {
  return Boolean(
    filters.query ||
      filters.programId ||
      filters.accountKind ||
      filters.accountStatus ||
      filters.personType ||
      filters.roleCode ||
      filters.serviceArea ||
      filters.scopeType,
  );
}

export function filtersToSearchParams(filters: AdminAccountFilters, page: number) {
  const params = new URLSearchParams();
  if (filters.query) params.set("q", filters.query);
  if (filters.programId) params.set("program", filters.programId);
  if (filters.accountKind) params.set("kind", filters.accountKind);
  if (filters.accountStatus) params.set("status", filters.accountStatus);
  if (filters.personType) params.set("person", filters.personType);
  if (filters.roleCode) params.set("role", filters.roleCode);
  if (filters.serviceArea) params.set("service", filters.serviceArea);
  if (filters.scopeType) params.set("scope", filters.scopeType);
  if (filters.pageSize !== 20) params.set("size", String(filters.pageSize));
  if (page > 1) params.set("page", String(page));
  return params.toString();
}
