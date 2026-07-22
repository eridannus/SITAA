import Image from "next/image";
import Link from "next/link";
import { login, loginWithGoogle } from "@/app/login/actions";

export function AuthenticationCard({ errorMessage, nextPath }: { errorMessage?: string; nextPath?: string | null }) {
  return (
    <div className="sitaa-surface w-full max-w-md rounded-3xl p-6 sm:p-8">
      <div className="text-center">
        <Image
          src="/brand/escudo-a.png"
          alt="Escudo de la FES Acatlán"
          width={1280}
          height={1491}
          sizes="(max-width: 639px) 42px, 55px"
          priority
          className="mx-auto h-12 w-auto sm:h-16"
        />
        <p className="mt-2 text-4xl font-black tracking-[0.12em] text-[var(--sitaa-blue-dark)] sm:text-5xl">SITAA</p>
        <h1 className="mx-auto mt-3 max-w-sm text-base font-bold leading-6 text-[var(--sitaa-text)] sm:text-lg">Sistema Integral de Tutorías y Asesorías Académicas</h1>
        <span className="mx-auto mt-4 block h-1 w-16 rounded-full bg-[var(--sitaa-gold)]" aria-hidden="true" />
      </div>

      {errorMessage && <div role="alert" className="sitaa-alert sitaa-alert--error mt-5">{errorMessage}</div>}

      <div className="mt-6 flex flex-col gap-5">
        <form action={loginWithGoogle} className="w-full">
          {nextPath && <input type="hidden" name="next" value={nextPath} />}
          <button type="submit" className="sitaa-primary-action w-full">Iniciar sesión con Google</button>
        </form>
        <Link href="/register" className="sitaa-secondary-action w-full">Registrarme</Link>
      </div>

      <details className="group mt-6 border-t border-slate-200 pt-4">
        <summary className="min-h-11 cursor-pointer list-none rounded-lg px-2 py-2 text-center text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)] marker:content-none">
          Acceso heredado con correo y contraseña
        </summary>
        <form action={login} className="mt-4 space-y-3">
          {nextPath && <input type="hidden" name="next" value={nextPath} />}
          <div>
            <label htmlFor="email" className="block text-sm font-semibold text-[var(--sitaa-text)]">Correo electrónico</label>
            <input id="email" name="email" type="email" autoComplete="email" required className="sitaa-field mt-1.5" />
          </div>
          <div>
            <label htmlFor="password" className="block text-sm font-semibold text-[var(--sitaa-text)]">Contraseña</label>
            <input id="password" name="password" type="password" autoComplete="current-password" required className="sitaa-field mt-1.5" />
          </div>
          <button type="submit" className="sitaa-secondary-action w-full">Entrar con acceso heredado</button>
        </form>
      </details>
      <p className="mt-5 text-center text-xs leading-5 text-[var(--sitaa-text-secondary)]">El acceso heredado se conserva temporalmente para cuentas existentes.</p>
    </div>
  );
}
