import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { loginPathWithNext } from "@/lib/navigation/safe-next-path";
import { finalizeExpiredAttendance } from "@/lib/attendance/finalize-expired-attendance";
import { CheckinCodeForm } from "./check-in-code-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Registrar asistencia" };

type Props = { searchParams: Promise<{ from?: string | string[] }> };

function param(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function CheckinPage({ searchParams }: Props) {
  const query = await searchParams;
  const fromActivities = param(query.from) === "activities";
  const currentPath = fromActivities ? "/check-in?from=activities" : "/check-in";
  await finalizeExpiredAttendance();
  const context = await getAuthenticatedUserContext();

  if (!context) redirect(loginPathWithNext(currentPath));

  return <main className="mx-auto max-w-3xl px-5 py-16 sm:px-8 sm:py-20">
    <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Asistencia</p>
    <h1 className="mt-3 text-3xl font-bold text-emerald-950 sm:text-4xl">Registrar asistencia</h1>
    <CheckinCodeForm returnHref="/activities" />
  </main>;
}
