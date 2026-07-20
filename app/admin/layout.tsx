import { redirect } from "next/navigation";
import { AuthenticatedAppShell } from "@/components/authenticated-app-shell";
import { canAccessAccountAdministration } from "@/lib/admin/authorization";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";

export default async function AdminLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?next=/admin/accounts");
  if (!canAccessAccountAdministration(context)) redirect("/dashboard");
  return <AuthenticatedAppShell>{children}</AuthenticatedAppShell>;
}
