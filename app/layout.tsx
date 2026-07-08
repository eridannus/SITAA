import type { Metadata } from "next";
import Link from "next/link";
import { AuthNavigationLink } from "@/components/auth-navigation-link";
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
              <Link href="/" className="flex items-center gap-3 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 transition hover:opacity-90" aria-label="Ir al inicio de SITAA">
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
                  className="hidden rounded-full border border-emerald-900/15 px-4 py-2 text-sm font-semibold text-emerald-900 transition hover:border-emerald-800 hover:bg-emerald-50 sm:block cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2"
                >
                  Estado del sistema
                </Link>
                <AuthNavigationLink />
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