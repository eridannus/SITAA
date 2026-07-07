import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import type { AssignmentScope, ServiceArea } from "@/types/sitaa";
import { logout } from "./actions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Panel",
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

function LogoutButton() {
  return (
    <form action={logout}>
      <button
        type="submit"
        className="rounded-full border border-slate-300 bg-white px-6 py-3 text-sm font-bold text-slate-700 transition hover:border-red-300 hover:bg-red-50 hover:text-red-700 focus:outline-none focus:ring-4 focus:ring-red-100"
      >
        Cerrar sesión
      </button>
    </form>
  );
}

export default async function DashboardPage() {
  const context = await getAuthenticatedUserContext();

  if (!context?.user.email) {
    redirect("/login?error=sesion-requerida");
  }

  if (context.error) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="rounded-3xl border border-red-200 bg-white p-8 shadow-xl shadow-red-950/5 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-red-700">
            Información no disponible
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-slate-900">
            No fue posible cargar tu información institucional
          </h1>
          <p className="mt-4 leading-7 text-slate-600">
            Intenta nuevamente. Si el problema continúa, contacta a la persona administradora de SITAA.
          </p>
          <div className="mt-8">
            <LogoutButton />
          </div>
        </div>
      </section>
    );
  }

  if (!context.profile) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="rounded-3xl border border-amber-200 bg-white p-8 shadow-xl shadow-amber-950/5 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            Activación pendiente
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-slate-900">
            Tu cuenta aún no está activada en SITAA
          </h1>
          <p className="mt-4 leading-7 text-slate-600">
            La cuenta de acceso existe, pero todavía no tiene un perfil institucional. Contacta a la persona administradora para completar la activación.
          </p>
          <p className="mt-4 text-sm text-slate-500">Cuenta: {context.user.email}</p>
          <div className="mt-8">
            <LogoutButton />
          </div>
        </div>
      </section>
    );
  }

  const { profile, primaryProgram, activeRoleAssignments, user } = context;

  return (
    <section className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="flex flex-col gap-6 rounded-3xl border border-emerald-950/10 bg-white p-8 shadow-xl shadow-emerald-950/5 sm:p-12 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
            Panel principal
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
            {profile.full_name || "Usuario de SITAA"}
          </h1>
          <dl className="mt-6 grid gap-4 text-sm sm:grid-cols-2">
            <div>
              <dt className="font-semibold text-slate-500">Correo</dt>
              <dd className="mt-1 text-base text-slate-900">{user.email}</dd>
            </div>
            {primaryProgram && (
              <div>
                <dt className="font-semibold text-slate-500">Programa académico principal</dt>
                <dd className="mt-1 text-base text-slate-900">{primaryProgram.name}</dd>
              </div>
            )}
          </dl>
        </div>
        <LogoutButton />
      </div>

      <div className="mt-8 rounded-3xl border border-slate-200 bg-white p-8 sm:p-10">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
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
              <article key={assignment.id} className="rounded-2xl border border-slate-200 bg-slate-50 p-6">
                <h3 className="text-lg font-bold text-slate-900">
                  {assignment.role?.name ?? "Rol institucional"}
                </h3>
                <dl className="mt-5 space-y-3 text-sm">
                  <div className="flex items-start justify-between gap-4">
                    <dt className="font-semibold text-slate-500">Alcance</dt>
                    <dd className="text-right text-slate-900">{scopeLabels[assignment.scope_type]}</dd>
                  </div>
                  <div className="flex items-start justify-between gap-4">
                    <dt className="font-semibold text-slate-500">Área de servicio</dt>
                    <dd className="text-right text-slate-900">{serviceAreaLabels[assignment.service_area]}</dd>
                  </div>
                  {assignment.division && (
                    <div className="flex items-start justify-between gap-4">
                      <dt className="font-semibold text-slate-500">División</dt>
                      <dd className="text-right text-slate-900">{assignment.division.name}</dd>
                    </div>
                  )}
                  {assignment.program && (
                    <div className="flex items-start justify-between gap-4">
                      <dt className="font-semibold text-slate-500">Programa</dt>
                      <dd className="text-right text-slate-900">{assignment.program.name}</dd>
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