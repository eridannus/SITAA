"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function target(activityId: string, status: string) {
  return "/activities/" + activityId + "?checkin=" + status + "#attendance-checkin";
}

export async function openAttendanceCheckin(activityId: string) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");
  const { error } = await supabase.rpc("open_activity_attendance_checkin", { target_activity_id: activityId });
  revalidatePath("/activities");
  revalidatePath("/activities/" + activityId);
  redirect(target(activityId, error ? "open-error" : "opened"));
}

export async function closeAttendanceCheckin(activityId: string, formData: FormData) {
  if (formData.get("confirmation") !== "confirmed") redirect(target(activityId, "close-error"));
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");
  const { error } = await supabase.rpc("close_activity_attendance_checkin", { target_activity_id: activityId });
  revalidatePath("/activities");
  revalidatePath("/activities/" + activityId);
  redirect(target(activityId, error ? "close-error" : "closed"));
}

export async function regenerateAttendanceCheckin(activityId: string, formData: FormData) {
  if (formData.get("confirmation") !== "confirmed") redirect(target(activityId, "regenerate-error"));
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");
  const closeResult = await supabase.rpc("close_activity_attendance_checkin", { target_activity_id: activityId });
  if (closeResult.error) {
    revalidatePath("/activities/" + activityId);
    redirect(target(activityId, "regenerate-error"));
  }
  const openResult = await supabase.rpc("open_activity_attendance_checkin", { target_activity_id: activityId });
  revalidatePath("/activities");
  revalidatePath("/activities/" + activityId);
  redirect(target(activityId, openResult.error ? "regenerate-error" : "regenerated"));
}
