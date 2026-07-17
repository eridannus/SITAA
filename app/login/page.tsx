import type { Metadata } from "next";
import Link from "next/link";
import { safeNextPath } from "@/lib/navigation/safe-next-path";
import { login, loginWithGoogle } from "./actions";

export const metadata: Metadata = {
  title: "Iniciar sesión",
};

const errorMessages: Record<string, string> = {
  configuracion:
    "El acceso no está configurado todavía. Contacta a la persona administradora.",
  credenciales:
    "No fue posible iniciar sesión. Verifica tu correo y contraseña.",
  "datos-incompletos": "Escribe tu correo y contraseña para continuar.",
  "sesion-requerida": "Inicia sesión para continuar.",
  "verificacion-pendiente": "Confirma tu correo antes de iniciar sesión.",
  google: "No fue posible iniciar sesión con Google. Intenta nuevamente.",
  "google-cancelado": "Se canceló el acceso con Google. Puedes intentarlo nuevamente.",
  "google-cuenta": "Google no pudo crear o vincular la cuenta. Intenta nuevamente.",
  "google-codigo": "La respuesta de Google no incluyó la autorización necesaria.",
  "google-intercambio": "No fue posible completar el intercambio de sesión con Google.",
  "google-sesion": "Google respondió, pero no fue posible recuperar la sesión autenticada.",
  "google-temporal": "Ocurrió un error temporal de autenticación. Intenta nuevamente.",
  "enlace-heredado": "El enlace de acceso heredado no es válido o ya expiró.",
};

type LoginPageProps = {
  searchParams: Promise<{ error?: string | string[]; next?: string | string[] }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const errorCode = Array.isArray(params.error) ? params.error[0] : params.error;
  const errorMessage = errorCode ? errorMessages[errorCode] : undefined;
  const nextPath = safeNextPath(params.next);

  return (
    <section className="mx-auto grid min-h-[70vh] max-w-6xl place-items-center px-5 py-16 sm:px-8">
      <div className="grid w-full max-w-4xl overflow-hidden rounded-3xl border border-emerald-950/10 bg-white shadow-2xl shadow-emerald-950/10 md:grid-cols-[0.9fr_1.1fr]">
        <div className="bg-emerald-950 p-8 text-white sm:p-10">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-300">
            Acceso a SITAA
          </p>
          <h1 className="mt-5 text-3xl font-bold tracking-tight sm:text-4xl">
            Bienvenido a SITAA
          </h1>
          <p className="mt-5 leading-7 text-emerald-100/80">
            Continúa con Google. Puedes usar una cuenta personal, pc.puma u otra cuenta de Google Workspace.
          </p>
        </div>

        <div className="p-8 sm:p-10">
          <h2 className="text-2xl font-bold text-slate-900">Iniciar sesión</h2>
          <p className="mt-2 text-sm leading-6 text-slate-600">Usa Google como acceso principal a SITAA.</p>

          {errorMessage && (
            <div
              role="alert"
              className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800"
            >
              {errorMessage}
            </div>
          )}

          <form action={loginWithGoogle} className="mt-7">
            {nextPath && <input type="hidden" name="next" value={nextPath} />}
            <button type="submit" className="w-full cursor-pointer rounded-xl bg-emerald-800 px-5 py-3 font-bold text-white shadow-lg shadow-emerald-900/15 transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
              Continuar con Google
            </button>
          </form>

          <div className="my-7 flex items-center gap-3" aria-hidden="true">
            <span className="h-px flex-1 bg-slate-200" />
            <span className="text-xs font-bold uppercase tracking-[0.16em] text-slate-400">Acceso heredado</span>
            <span className="h-px flex-1 bg-slate-200" />
          </div>
          <h3 className="text-base font-bold text-slate-800">Acceso con correo y contraseña</h3>
          <p className="mt-1 text-sm leading-6 text-slate-500">Disponible temporalmente para cuentas existentes. No crea cuentas nuevas.</p>

          <form action={login} className="mt-5 space-y-5">
            {nextPath && <input type="hidden" name="next" value={nextPath} />}
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
              className="w-full rounded-xl bg-emerald-800 px-5 py-3 font-bold text-white shadow-lg shadow-emerald-900/15 transition hover:bg-emerald-900 focus:outline-none focus:ring-4 focus:ring-emerald-200 cursor-pointer disabled:cursor-not-allowed disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2"
            >
              Entrar con acceso heredado
            </button>
          </form>
          <p className="mt-6 text-center text-sm text-slate-600">
            ¿Todavía no tienes cuenta SITAA?{" "}
            <Link href="/register" className="cursor-pointer font-bold text-emerald-800 underline decoration-emerald-400 underline-offset-4 hover:text-emerald-950">
              Registrarme
            </Link>
          </p>
        </div>
      </div>
    </section>
  );
}
