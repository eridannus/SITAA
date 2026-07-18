import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { finalizeExpiredAttendance } from "@/lib/attendance/finalize-expired-attendance";
import { checkinMessageFromResult } from "@/lib/check-in/check-in-result";
import { loginPathWithNext } from "@/lib/navigation/safe-next-path";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Confirmar asistencia" };

type Props = { params: Promise<{ token: string }> };

export default async function TokenCheckinPage({ params }: Props) {
  const { token } = await params;
  const currentPath = "/check-in/" + encodeURIComponent(token);
  await finalizeExpiredAttendance();
  const context = await getAuthenticatedUserContext();

  if (!context) redirect(loginPathWithNext(currentPath));

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("check_in_activity", { checkin_input: token });
  const result = checkinMessageFromResult(data, error);
  const isError = result.status === "error";
  const isWarning = result.status === "invalid" || result.status === "not-participant";
  const messageClass = isError
    ? "sitaa-alert--error"
    : isWarning
      ? "sitaa-alert--warning"
      : "sitaa-alert--success";
  return <main className="mx-auto max-w-3xl px-5 py-16 sm:px-8 sm:py-20">
    <p className="sitaa-section-eyebrow">Asistencia</p>
    <h1 className="sitaa-section-title mt-3 text-3xl sm:text-4xl">Confirmación de asistencia</h1>
    <div role={isError || isWarning ? "alert" : "status"} className={"sitaa-alert mt-8 p-7 " + messageClass}>
      {result.activityTitle ? <p className="mb-3 break-words text-sm font-semibold opacity-80">{result.activityTitle}</p> : null}
      <p className="break-words text-lg font-bold">{result.message}</p>
    </div>
    <div className="mt-7 flex flex-wrap gap-3">
      <Link href="/activities" className="sitaa-primary-action px-6">Ver mis actividades</Link>
    </div>
  </main>;
}
