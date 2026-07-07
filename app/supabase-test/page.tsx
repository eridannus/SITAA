import type { Metadata } from "next";
import { createSupabaseClient } from "@/lib/supabase/client";

export const metadata: Metadata = {
  title: "Prueba de Supabase",
};

export const dynamic = "force-dynamic";

type ConnectionStatus =
  | { state: "connected" }
  | { state: "not-configured" }
  | { state: "error" };

async function getConnectionStatus(): Promise<ConnectionStatus> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return { state: "not-configured" };
  }

  try {
    const supabase = createSupabaseClient();
    const { error } = await supabase
      .schema("public")
      .from("system_health")
      .select("*")
      .limit(1);

    if (error) {
      return { state: "error" };
    }

    return { state: "connected" };
  } catch {
    return { state: "error" };
  }
}

export default async function SupabaseTestPage() {
  const status = await getConnectionStatus();
  const isConnected = status.state === "connected";

  return (
    <section className="mx-auto grid min-h-[65vh] max-w-6xl place-items-center px-5 py-16 sm:px-8">
      <div className="w-full max-w-xl rounded-3xl border border-emerald-900/10 bg-white p-8 shadow-xl shadow-emerald-950/5 sm:p-12">
        <div
          className={`grid size-14 place-items-center rounded-2xl text-2xl font-bold ${
            isConnected
              ? "bg-emerald-100 text-emerald-800"
              : "bg-amber-100 text-amber-800"
          }`}
          aria-hidden="true"
        >
          {isConnected ? "✓" : "!"}
        </div>
        <p className="mt-7 text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
          Diagnóstico de integración
        </p>

        {status.state === "connected" && (
          <>
            <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
              Supabase conectado
            </h1>
            <p className="mt-4 leading-7 text-slate-600">
              La aplicación pudo consultar correctamente la tabla pública de estado.
            </p>
          </>
        )}

        {status.state === "not-configured" && (
          <>
            <h1 className="mt-3 text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
              Supabase no está configurado
            </h1>
            <p className="mt-4 leading-7 text-slate-600">
              Agrega las variables públicas requeridas en tu archivo local de entorno y vuelve a cargar esta página.
            </p>
          </>
        )}

        {status.state === "error" && (
          <>
            <h1 className="mt-3 text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
              No fue posible conectar con Supabase
            </h1>
            <p className="mt-4 leading-7 text-slate-600">
              Verifica la configuración y que la tabla pública <code className="rounded bg-slate-100 px-1.5 py-0.5 text-sm">system_health</code> exista y permita lectura con la clave pública.
            </p>
          </>
        )}
      </div>
    </section>
  );
}