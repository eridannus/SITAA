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
      className="sitaa-primary-action min-h-11 px-4 py-2 text-sm"
    >
      {isAuthenticated ? "Inicio" : "Iniciar sesión"}
    </Link>
  );
}
