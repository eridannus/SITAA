import { AuthenticatedAppShell } from "@/components/authenticated-app-shell";

export default function CatalogsLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <AuthenticatedAppShell>{children}</AuthenticatedAppShell>;
}
