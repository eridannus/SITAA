import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityFormOptions } from "@/types/activities";
import type { CatalogRow, AcademicPeriod } from "@/types/catalogs";
import type { Profile } from "@/types/sitaa";
import { createActivity } from "../actions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Nueva actividad",
};

const errorMessages: Record<string, string> = {
  "perfil-requerido": "Tu cuenta necesita un perfil institucional activo para crear actividades.",
  "campos-requeridos": "Completa el título, programa, tipo de actividad, servicio y modalidad.",
  "datos-invalidos": "Revisa las fechas y la longitud de los datos capturados.",
  "catalogo-invalido": "Una de las opciones seleccionadas ya no está disponible.",
  creacion: "No fue posible crear la actividad. Verifica tus permisos e intenta nuevamente.",
};

type NewActivityPageProps = {
  searchParams: Promise<{ error?: string | string[] }>;
};

function getLabel(item: CatalogRow) {
  return item.label?.trim() || item.name?.trim() || item.code;
}

function CatalogOptions({ items }: { items: CatalogRow[] }) {
  return items.map((item) => (
    <option key={item.id} value={item.code}>
      {getLabel(item)}
    </option>
  ));
}

export default async function NewActivityPage({ searchParams }: NewActivityPageProps) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?error=sesion-requerida");
  }

  const { data: profileData, error: profileError } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8">
        <h1 className="text-3xl font-bold text-slate-900">No fue posible preparar la actividad</h1>
        <p className="mt-4 text-slate-600">Intenta nuevamente más tarde.</p>
      </section>
    );
  }

  const profile = profileData as Profile | null;

  if (!profile) {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8">
        <div className="rounded-3xl border border-amber-200 bg-white p-8 sm:p-12">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">Activación pendiente</p>
          <h1 className="mt-3 text-3xl font-bold text-slate-900">Necesitas un perfil activo en SITAA</h1>
          <p className="mt-4 leading-7 text-slate-600">
            Tu cuenta existe, pero aún no tiene un perfil institucional habilitado para crear actividades.
          </p>
        </div>
      </section>
    );
  }

  let options: ActivityFormOptions;

  try {
    options = await getActivityFormOptions();
  } catch {
    return (
      <section className="mx-auto max-w-4xl px-5 py-16 sm:px-8">
        <h1 className="text-3xl font-bold text-slate-900">No fue posible cargar el formulario</h1>
        <p className="mt-4 text-slate-600">Los catálogos operativos no están disponibles.</p>
      </section>
    );
  }

  const params = await searchParams;
  const errorCode = Array.isArray(params.error) ? params.error[0] : params.error;
  const errorMessage = errorCode ? errorMessages[errorCode] : undefined;
  const inputClass =
    "mt-2 w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-slate-900 outline-none transition focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100";

  return (
    <main className="mx-auto max-w-5xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Operación académica</p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">Nueva actividad</h1>
          <p className="mt-4 max-w-2xl leading-7 text-slate-600">
            Registra la información base. Participantes, asistencia y formularios se incorporarán después.
          </p>
        </div>
        <Link href="/activities" className="rounded-full border border-slate-300 px-6 py-3 text-center text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800">
          Volver a actividades
        </Link>
      </div>

      <div className="mt-9 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
        {errorMessage && (
          <div role="alert" className="mb-7 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800">
            {errorMessage}
          </div>
        )}

        <form action={createActivity} className="grid gap-6 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label htmlFor="title" className="block text-sm font-semibold text-slate-700">Título</label>
            <input id="title" name="title" required maxLength={200} className={inputClass} />
          </div>
          <div className="sm:col-span-2">
            <label htmlFor="description" className="block text-sm font-semibold text-slate-700">Descripción</label>
            <textarea id="description" name="description" rows={4} maxLength={5000} className={inputClass} />
          </div>
          <div>
            <label htmlFor="academic_period_id" className="block text-sm font-semibold text-slate-700">Periodo académico</label>
            <select id="academic_period_id" name="academic_period_id" className={inputClass}>
              <option value="">Sin periodo asignado</option>
              {options.academicPeriods.map((period: AcademicPeriod) => (
                <option key={period.id} value={period.id}>{getLabel(period)}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="program_id" className="block text-sm font-semibold text-slate-700">Programa académico</label>
            <select id="program_id" name="program_id" defaultValue={profile.primary_program_id ?? ""} required className={inputClass}>
              <option value="" disabled>Selecciona un programa</option>
              {options.programs.map((program) => (
                <option key={program.id} value={program.id}>{program.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="activity_type_code" className="block text-sm font-semibold text-slate-700">Tipo de actividad</label>
            <select id="activity_type_code" name="activity_type_code" defaultValue="" required className={inputClass}>
              <option value="" disabled>Selecciona un tipo</option>
              <CatalogOptions items={options.activityTypes} />
            </select>
          </div>
          <div>
            <label htmlFor="service_type_code" className="block text-sm font-semibold text-slate-700">Tipo de servicio</label>
            <select id="service_type_code" name="service_type_code" defaultValue="" required className={inputClass}>
              <option value="" disabled>Selecciona un servicio</option>
              <CatalogOptions items={options.serviceTypes} />
            </select>
          </div>
          <div>
            <label htmlFor="attention_category_code" className="block text-sm font-semibold text-slate-700">Categoría de atención</label>
            <select id="attention_category_code" name="attention_category_code" className={inputClass}>
              <option value="">Sin categoría</option>
              <CatalogOptions items={options.attentionCategories} />
            </select>
          </div>
          <div>
            <label htmlFor="modality_code" className="block text-sm font-semibold text-slate-700">Modalidad</label>
            <select id="modality_code" name="modality_code" defaultValue="" required className={inputClass}>
              <option value="" disabled>Selecciona una modalidad</option>
              <CatalogOptions items={options.modalities} />
            </select>
          </div>
          <div>
            <label htmlFor="location_type_code" className="block text-sm font-semibold text-slate-700">Tipo de ubicación</label>
            <select id="location_type_code" name="location_type_code" className={inputClass}>
              <option value="">Sin tipo de ubicación</option>
              <CatalogOptions items={options.locationTypes} />
            </select>
          </div>
          <div>
            <label htmlFor="location_detail" className="block text-sm font-semibold text-slate-700">Detalle de ubicación</label>
            <input id="location_detail" name="location_detail" maxLength={500} placeholder="Aula, edificio o enlace" className={inputClass} />
          </div>
          <div>
            <label htmlFor="starts_at" className="block text-sm font-semibold text-slate-700">Inicio</label>
            <input id="starts_at" name="starts_at" type="datetime-local" className={inputClass} />
          </div>
          <div>
            <label htmlFor="ends_at" className="block text-sm font-semibold text-slate-700">Fin</label>
            <input id="ends_at" name="ends_at" type="datetime-local" className={inputClass} />
          </div>
          <div className="sm:col-span-2 rounded-xl bg-slate-50 px-4 py-3 text-sm leading-6 text-slate-600">
            El estado será <strong>Programada</strong> si indicas una fecha de inicio; de lo contrario será <strong>Borrador</strong>.
          </div>
          <div className="sm:col-span-2">
            <button type="submit" className="rounded-full bg-emerald-800 px-7 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus:outline-none focus:ring-4 focus:ring-emerald-200">
              Crear actividad
            </button>
          </div>
        </form>
      </div>
    </main>
  );
}