import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Avatar } from "@/components/avatar";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { getDisplayName, getInitials, getSafeGoogleAvatarUrl } from "@/lib/auth/user-display";
import type {
  AssignmentScope,
  InstitutionalIdType,
  PersonType,
  ServiceArea,
} from "@/types/sitaa";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Inicio",
};

const scopeLabels: Record<AssignmentScope, string> = {
  own: "Propio",
  program: "Programa",
  division: "División",
  system: "Sistema",
};

const serviceAreaLabels: Record<ServiceArea, string> = {
  tutoring: "Tutorías",
  advising: "Asesorías",
  both: "Tutorías y asesorías",
  logistics: "Logística",
  technical: "Técnica",
};

const personTypeLabels: Record<PersonType, string> = {
  student: "Alumno",
  professor: "Profesor",
};

const institutionalIdTypeLabels: Record<InstitutionalIdType, string> = {
  student_account: "Número de cuenta",
  worker_number: "Número de trabajador",
};

function getRoleLabel(
  role: { label?: string | null; name?: string | null; code: string } | null,
  roleCode: string,
) {
  return role?.label?.trim() || role?.name?.trim() || roleCode;
}

export default async function DashboardPage() {
  const context = await getAuthenticatedUserContext();

  if (!context?.user.email) {
    redirect("/login?error=sesion-requerida");
  }

  if (context.error) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="sitaa-alert sitaa-alert--error p-8 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-red-700">
            Información no disponible
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-slate-900">
            No fue posible cargar tu información institucional
          </h1>
          <p className="mt-4 leading-7 text-slate-600">
            Intenta nuevamente. Si el problema continúa, contacta a la persona administradora de SITAA.
          </p>
        </div>
      </section>
    );
  }

  if (!context.profile) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="sitaa-alert sitaa-alert--warning p-8 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            Activación pendiente
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-slate-900">
            Tu cuenta aún no está activada en SITAA
          </h1>
          <p className="mt-4 leading-7 text-slate-600">
            La cuenta de acceso existe, pero todavía no tiene un perfil institucional. Contacta a la persona administradora para completar la activación.
          </p>
          <p className="mt-4 break-all text-sm text-slate-500">Cuenta: {context.user.email}</p>
        </div>
      </section>
    );
  }

  const { profile, primaryProgram, activeRoleAssignments, user } = context;
  const displayName = getDisplayName(profile, user);

  return (
    <section className="mx-auto max-w-6xl px-4 py-10 sm:px-8 sm:py-14">
      <div className="sitaa-surface rounded-3xl p-6 sm:p-9">
        <div className="flex min-w-0 flex-col gap-5 sm:flex-row sm:items-center">
          <Avatar imageUrl={getSafeGoogleAvatarUrl(user)} initials={getInitials(displayName)} alt={`Foto de perfil de ${displayName}`} size="large" />
          <div className="min-w-0">
            <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sitaa-gold-dark)]">Inicio</p>
            <h1 className="mt-1 text-3xl font-bold tracking-tight text-[var(--sitaa-blue-dark)] sm:text-4xl">{displayName}</h1>
            <p className="mt-2 text-[var(--sitaa-text-secondary)]">Resumen de tu cuenta institucional y accesos vigentes.</p>
          </div>
        </div>

        <dl className="mt-8 grid min-w-0 gap-4 text-sm sm:grid-cols-2 lg:grid-cols-3">
            <div className="rounded-2xl bg-[var(--sitaa-surface-subdued)] p-4">
              <dt className="font-semibold text-slate-500">Tipo de cuenta</dt>
              <dd className="mt-1 text-base text-slate-900">{profile.account_kind === "technical" ? "Técnica interna" : "Institucional"}</dd>
            </div>
            {profile.person_type && (
              <div className="rounded-2xl bg-[var(--sitaa-surface-subdued)] p-4">
                <dt className="font-semibold text-slate-500">Tipo de persona</dt>
                <dd className="mt-1 text-base text-slate-900">{personTypeLabels[profile.person_type]}</dd>
              </div>
            )}
            {profile.institutional_id_type && profile.institutional_id_value && (
              <div className="rounded-2xl bg-[var(--sitaa-surface-subdued)] p-4">
                <dt className="font-semibold text-slate-500">
                  {institutionalIdTypeLabels[profile.institutional_id_type]}
                </dt>
                <dd className="mt-1 break-words text-base text-slate-900">{profile.institutional_id_value}</dd>
              </div>
            )}
            {primaryProgram ? (
              <div className="rounded-2xl bg-[var(--sitaa-surface-subdued)] p-4">
                <dt className="font-semibold text-slate-500">Programa académico principal</dt>
                <dd className="mt-1 text-base text-slate-900">{primaryProgram.name}</dd>
              </div>
            ) : profile.account_kind !== "technical" ? (
              <div className="sitaa-alert sitaa-alert--warning">
                <dt className="font-semibold text-amber-800">Programa académico principal</dt>
                <dd className="mt-1 text-sm font-semibold text-amber-900">Programa no asignado</dd>
              </div>
            ) : null}
            <div className="min-w-0 rounded-2xl bg-[var(--sitaa-surface-subdued)] p-4 sm:col-span-2 lg:col-span-3">
              <dt className="font-semibold text-slate-500">Correo</dt>
              <dd className="sitaa-wrap-anywhere mt-1 text-base text-slate-900">{user.email}</dd>
            </div>
        </dl>

      </div>

      <div className="mt-8 rounded-3xl border border-slate-200 bg-white p-6 sm:p-9">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--sitaa-gold-dark)]">
            Acceso vigente
          </p>
          <h2 className="mt-2 text-2xl font-bold text-slate-900">Asignaciones de rol activas</h2>
        </div>

        {activeRoleAssignments.length === 0 ? (
          <p className="mt-6 rounded-2xl bg-slate-50 p-5 leading-7 text-slate-600">
            Tu perfil está activo, pero no tiene asignaciones de rol vigentes.
          </p>
        ) : (
          <div className="mt-7 grid gap-4 md:grid-cols-2">
            {activeRoleAssignments.map((assignment) => (
              <article key={assignment.id} className="min-w-0 rounded-2xl border border-slate-200 bg-slate-50 p-6">
                <h3 className="text-lg font-bold text-slate-900">
                  {getRoleLabel(assignment.role, assignment.role_code)}
                </h3>
                <dl className="mt-5 space-y-3 text-sm">
                  <div className="flex items-start justify-between gap-4">
                    <dt className="font-semibold text-slate-500">Alcance</dt>
                    <dd className="min-w-0 break-words text-right text-slate-900">{scopeLabels[assignment.scope_type]}</dd>
                  </div>
                  <div className="flex items-start justify-between gap-4">
                    <dt className="font-semibold text-slate-500">Área de servicio</dt>
                    <dd className="min-w-0 break-words text-right text-slate-900">{serviceAreaLabels[assignment.service_area]}</dd>
                  </div>
                  {assignment.division && (
                    <div className="flex items-start justify-between gap-4">
                      <dt className="font-semibold text-slate-500">División</dt>
                      <dd className="min-w-0 break-words text-right text-slate-900">{assignment.division.name}</dd>
                    </div>
                  )}
                  {assignment.program && (
                    <div className="flex items-start justify-between gap-4">
                      <dt className="font-semibold text-slate-500">Programa</dt>
                      <dd className="min-w-0 break-words text-right text-slate-900">{assignment.program.name}</dd>
                    </div>
                  )}
                </dl>
              </article>
            ))}
          </div>
        )}

        <p className="mt-7 text-sm leading-6 text-slate-500">
          Los paneles especializados y permisos por función se incorporarán en etapas posteriores.
        </p>
      </div>
    </section>
  );
}
