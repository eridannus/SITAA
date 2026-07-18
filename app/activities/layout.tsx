import { AuthenticatedAppShell } from "@/components/authenticated-app-shell";

export default function ActivitiesLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <AuthenticatedAppShell>{children}</AuthenticatedAppShell>;
}
