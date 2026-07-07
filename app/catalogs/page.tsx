import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getActiveCatalogs } from "@/lib/catalogs/get-active-catalogs";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { CatalogRow, OperationalCatalogs } from "@/types/catalogs";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Catálogos operativos",
};

type CatalogSection = {
  key: keyof OperationalCatalogs;
  title: string;
  description: string;
};

const sections: CatalogSection[] = [
  {
    key: "academicPeriods",
    title: "Periodos académicos",
    description: "Periodos disponibles para organizar la operación académica.",
  },
  {
    key: "activityTypes",
    title: "Tipos de actividad",
    description: "Clases de actividades que podrá registrar SITAA.",
  },
  {
    key: "serviceTypes",
    title: "Tipos de servicio",
    description: "Servicios institucionales de tutoría y asesoría.",
  },
  {
    key: "attentionCategories",
    title: "Categorías de atención",
    description: "Clasificaciones para describir el propósito de la atención.",
  },
  {
    key: "activityModalities",
    title: "Modalidades de actividad",
    description: "Formas previstas para realizar una actividad.",
  },
  {
    key: "activityStatuses",
    title: "Estados de actividad",
    description: "Etapas controladas del ciclo de una actividad.",
  },
  {
    key: "locationTypes",
    title: "Tipos de ubicación",
    description: "Clasificaciones para lugares físicos o virtuales.",
  },
  {
    key: "participantRoles",
    title: "Roles de participación",
    description: "Funciones que una persona puede tener dentro de una actividad.",
  },
];

function getItemLabel(item: CatalogRow) {
  return item.label?.trim() || item.name?.trim() || item.code;
}

function CatalogCard({ section, items }: { section: CatalogSection; items: CatalogRow[] }) {
  return (
    <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
      <div className="border-b border-slate-100 pb-5">
        <h2 className="text-xl font-bold text-emerald-950">{section.title}</h2>
        <p className="mt-2 text-sm leading-6 text-slate-500">{section.description}</p>
      </div>

      {items.length === 0 ? (
        <p className="py-6 text-sm text-slate-500">No hay valores activos en este catálogo.</p>
      ) : (
        <ul className="divide-y divide-slate-100">
          {items.map((item) => (
            <li key={item.id} className="py-5 first:pt-6 last:pb-0">
              <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h3 className="font-semibold text-slate-900">{getItemLabel(item)}</h3>
                  {item.description && (
                    <p className="mt-1 text-sm leading-6 text-slate-600">{item.description}</p>
                  )}
                </div>
                <code className="w-fit rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-800">
                  {item.code}
                </code>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default async function CatalogsPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?error=sesion-requerida");
  }

  let catalogs: OperationalCatalogs;

  try {
    catalogs = await getActiveCatalogs();
  } catch {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
        <div className="rounded-3xl border border-red-200 bg-white p-8 shadow-xl shadow-red-950/5 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-red-700">
            Catálogos no disponibles
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-slate-900">
            No fue posible cargar los catálogos operativos
          </h1>
          <p className="mt-4 leading-7 text-slate-600">
            Intenta nuevamente. Si el problema continúa, contacta a la persona administradora de SITAA.
          </p>
        </div>
      </section>
    );
  }

  return (
    <main className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="max-w-3xl">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
          Configuración operativa
        </p>
        <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
          Catálogos vigentes
        </h1>
        <p className="mt-4 text-lg leading-8 text-slate-600">
          Consulta los valores activos que SITAA utilizará para organizar sus procesos. La edición se incorporará en una etapa posterior.
        </p>
      </div>

      <div className="mt-10 grid gap-6 lg:grid-cols-2">
        {sections.map((section) => (
          <CatalogCard
            key={section.key}
            section={section}
            items={catalogs[section.key] as CatalogRow[]}
          />
        ))}
      </div>
    </main>
  );
}