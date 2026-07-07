import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "SITAA",
    template: "%s | SITAA",
  },
  description: "Sistema Integral de Tutorías y Asesorías Académicas.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body>
        <div className="flex min-h-screen flex-col">
          <header className="border-b border-emerald-950/10 bg-white/90 backdrop-blur">
            <div className="mx-auto flex max-w-6xl items-center justify-between px-5 py-4 sm:px-8">
              <Link href="/" className="flex items-center gap-3" aria-label="Ir al inicio de SITAA">
                <span className="grid size-10 place-items-center rounded-xl bg-emerald-800 text-sm font-bold tracking-wide text-white">
                  ST
                </span>
                <span>
                  <span className="block text-base font-bold tracking-[0.12em] text-emerald-950">SITAA</span>
                  <span className="hidden text-xs text-slate-500 sm:block">Tutorías y asesorías académicas</span>
                </span>
              </Link>
              <nav className="flex items-center gap-2" aria-label="Navegación principal">
                <Link
                  href="/health"
                  className="hidden rounded-full border border-emerald-900/15 px-4 py-2 text-sm font-semibold text-emerald-900 transition hover:border-emerald-800 hover:bg-emerald-50 sm:block"
                >
                  Estado del sistema
                </Link>
                <Link
                  href="/login"
                  className="rounded-full bg-emerald-800 px-4 py-2 text-sm font-bold text-white transition hover:bg-emerald-900"
                >
                  Iniciar sesión
                </Link>
              </nav>
            </div>
          </header>
          <main className="flex-1">{children}</main>
          <footer className="border-t border-emerald-950/10 bg-white">
            <div className="mx-auto max-w-6xl px-5 py-6 text-sm text-slate-500 sm:px-8">
              SITAA · Sistema Integral de Tutorías y Asesorías Académicas
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}