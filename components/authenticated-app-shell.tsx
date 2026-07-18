import { SiteHeader } from "@/components/site-header";

export function AuthenticatedAppShell({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <div className="flex min-h-dvh min-w-0 flex-col">
      <SiteHeader />
      <main className="min-w-0 flex-1">{children}</main>
    </div>
  );
}
