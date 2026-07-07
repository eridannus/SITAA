import type { Metadata } from "next";
import { login } from "./actions";

export const metadata: Metadata = {
  title: "Iniciar sesión",
};

const errorMessages: Record<string, string> = {
  configuracion:
    "El acceso no está configurado todavía. Contacta a la persona administradora.",
  credenciales:
    "No fue posible iniciar sesión. Verifica tu correo y contraseña.",
  "datos-incompletos": "Escribe tu correo y contraseña para continuar.",
  "sesion-requerida": "Inicia sesión para acceder al panel.",
};

type LoginPageProps = {
  searchParams: Promise<{ error?: string | string[] }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const errorCode = Array.isArray(params.error) ? params.error[0] : params.error;
  const errorMessage = errorCode ? errorMessages[errorCode] : undefined;

  return (
    <section className="mx-auto grid min-h-[70vh] max-w-6xl place-items-center px-5 py-16 sm:px-8">
      <div className="grid w-full max-w-4xl overflow-hidden rounded-3xl border border-emerald-950/10 bg-white shadow-2xl shadow-emerald-950/10 md:grid-cols-[0.9fr_1.1fr]">
        <div className="bg-emerald-950 p-8 text-white sm:p-10">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-300">
            Acceso institucional
          </p>
          <h1 className="mt-5 text-3xl font-bold tracking-tight sm:text-4xl">
            Bienvenido a SITAA
          </h1>
          <p className="mt-5 leading-7 text-emerald-100/80">
            Ingresa con la cuenta que te proporcionó la institución para consultar tu panel.
          </p>
        </div>

        <div className="p-8 sm:p-10">
          <h2 className="text-2xl font-bold text-slate-900">Iniciar sesión</h2>
          <p className="mt-2 text-sm leading-6 text-slate-600">
            El registro público de cuentas no está disponible.
          </p>

          {errorMessage && (
            <div
              role="alert"
              className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800"
            >
              {errorMessage}
            </div>
          )}

          <form action={login} className="mt-7 space-y-5">
            <div>
              <label htmlFor="email" className="block text-sm font-semibold text-slate-700">
                Correo electrónico
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="mt-2 w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100"
                placeholder="nombre@institucion.edu"
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-semibold text-slate-700">
                Contraseña
              </label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                className="mt-2 w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-slate-900 outline-none transition focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100"
              />
            </div>

            <button
              type="submit"
              className="w-full rounded-xl bg-emerald-800 px-5 py-3 font-bold text-white shadow-lg shadow-emerald-900/15 transition hover:bg-emerald-900 focus:outline-none focus:ring-4 focus:ring-emerald-200"
            >
              Entrar
            </button>
          </form>
        </div>
      </div>
    </section>
  );
}