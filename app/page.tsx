import Link from "next/link";

const capacidades = [
  {
    numero: "01",
    titulo: "Planeación académica",
    descripcion: "Organiza tutorías y asesorías por periodo, programa y grupo.",
  },
  {
    numero: "02",
    titulo: "Seguimiento claro",
    descripcion: "Centraliza sesiones, asistencia y evaluación en un solo lugar.",
  },
  {
    numero: "03",
    titulo: "Información útil",
    descripcion: "Consulta avances y genera reportes para la toma de decisiones.",
  },
];

export default function Home() {
  return (
    <>
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_right,_rgba(16,185,129,0.16),_transparent_38%),linear-gradient(180deg,#ffffff_0%,#f7f8f5_100%)]" />
        <div className="mx-auto grid max-w-6xl gap-12 px-5 py-20 sm:px-8 sm:py-28 lg:grid-cols-[1.25fr_0.75fr] lg:items-center lg:py-36">
          <div>
            <p className="mb-5 text-sm font-bold uppercase tracking-[0.22em] text-emerald-700">
              Acompañamiento académico
            </p>
            <h1 className="max-w-4xl text-4xl font-bold leading-tight tracking-tight text-emerald-950 sm:text-6xl">
              Cada tutoría cuenta. Cada estudiante también.
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">
              SITAA reúne la planeación, el seguimiento y la evaluación de tutorías y asesorías académicas en una experiencia sencilla y confiable.
            </p>
            <div className="mt-9 flex flex-col gap-3 sm:flex-row">
              <a
                href="#capacidades"
                className="rounded-full bg-emerald-800 px-6 py-3 text-center text-sm font-bold text-white shadow-lg shadow-emerald-900/15 transition hover:bg-emerald-900"
              >
                Conocer el sistema
              </a>
              <Link
                href="/health"
                className="rounded-full border border-slate-300 bg-white px-6 py-3 text-center text-sm font-bold text-slate-700 transition hover:border-emerald-700 hover:text-emerald-800"
              >
                Verificar servicio
              </Link>
            </div>
          </div>

          <div className="rounded-3xl border border-white/80 bg-emerald-950 p-7 text-white shadow-2xl shadow-emerald-950/20 sm:p-9">
            <p className="text-sm font-semibold text-emerald-300">Propósito</p>
            <p className="mt-4 text-2xl font-semibold leading-9">
              Fortalecer el acompañamiento académico con información organizada, oportuna y segura.
            </p>
            <div className="mt-8 border-t border-white/15 pt-6 text-sm leading-6 text-emerald-100/80">
              Diseño inicial · Plataforma en construcción
            </div>
          </div>
        </div>
      </section>

      <section id="capacidades" className="border-t border-emerald-950/10 bg-white">
        <div className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-20">
          <div className="max-w-2xl">
            <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Una visión integral</p>
            <h2 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
              Del plan semestral al reporte institucional
            </h2>
          </div>
          <div className="mt-10 grid gap-5 md:grid-cols-3">
            {capacidades.map((capacidad) => (
              <article key={capacidad.numero} className="rounded-2xl border border-slate-200 bg-slate-50 p-6">
                <span className="text-sm font-bold text-emerald-700">{capacidad.numero}</span>
                <h3 className="mt-8 text-xl font-bold text-slate-900">{capacidad.titulo}</h3>
                <p className="mt-3 leading-7 text-slate-600">{capacidad.descripcion}</p>
              </article>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}