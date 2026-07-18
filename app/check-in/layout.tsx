import { AuthenticatedAppShell } from "@/components/authenticated-app-shell";

export default function CheckInLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <AuthenticatedAppShell>{children}</AuthenticatedAppShell>;
}
