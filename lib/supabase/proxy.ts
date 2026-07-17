import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("error", "configuracion");
    return NextResponse.redirect(loginUrl);
  }

  let response = NextResponse.next({ request });
  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value);
        });

        response = NextResponse.next({ request });

        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("error", "sesion-requerida");
    loginUrl.searchParams.set("next", request.nextUrl.pathname + request.nextUrl.search);
    return NextResponse.redirect(loginUrl);
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();
  const accountStatus = profile?.account_status ?? (profile?.is_active === false ? "inactive" : "active");
  const isStatusPage = request.nextUrl.pathname === "/account-status";
  const isCompletionPage = request.nextUrl.pathname === "/complete-registration"
    || request.nextUrl.pathname.startsWith("/complete-registration/");

  if (profileError || !profile) {
    if (!isStatusPage) {
      const statusUrl = new URL("/account-status", request.url);
      return NextResponse.redirect(statusUrl);
    }
    return response;
  }

  if (accountStatus === "pending_registration") {
    if (!isCompletionPage) return NextResponse.redirect(new URL("/complete-registration", request.url));
    return response;
  }

  if (accountStatus === "inactive") {
    if (!isStatusPage) return NextResponse.redirect(new URL("/account-status", request.url));
    return response;
  }

  if (isStatusPage || isCompletionPage) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  return response;
}
