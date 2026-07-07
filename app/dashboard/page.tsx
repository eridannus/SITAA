import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { logout } from "./actions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Panel",
};

export default async function DashboardPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect("/login?error=sesion-requerida");
  }

  return (
    <section className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="rounded-3xl border border-emerald-950/10 bg-white p-8 shadow-xl shadow-emerald-950/5 sm:p-12">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">
          Panel principal
        </p>
        <h1 className="mt-3 text-3xl font-bold tracking-tight text-emerald-950 sm:text-4xl">
          Sesión iniciada
        </h1>
        <p className="mt-5 text-lg leading-8 text-slate-600">
          Has ingresado como <strong className="font-semibold text-slate-900">{user.email}</strong>.
        </p>
        <p className="mt-3 max-w-2xl leading-7 text-slate-500">
          Los paneles por rol y las funciones académicas se incorporarán en etapas posteriores.
        </p>
        <form action={logout} className="mt-9">
          <button
            type="submit"
            className="rounded-full border border-slate-300 bg-white px-6 py-3 text-sm font-bold text-slate-700 transition hover:border-red-300 hover:bg-red-50 hover:text-red-700 focus:outline-none focus:ring-4 focus:ring-red-100"
          >
            Cerrar sesión
          </button>
        </form>
      </div>
    </section>
  );
}