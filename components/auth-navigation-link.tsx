import Link from "next/link";
import { connection } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function AuthNavigationLink() {
  await connection();

  let isAuthenticated = false;

  try {
    const supabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    isAuthenticated = Boolean(user);
  } catch {
    isAuthenticated = false;
  }

  return (
    <Link
      href={isAuthenticated ? "/dashboard" : "/login"}
      className="rounded-full bg-emerald-800 px-4 py-2 text-sm font-bold text-white transition hover:bg-emerald-900 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2"
    >
      {isAuthenticated ? "Panel" : "Iniciar sesión"}
    </Link>
  );
}