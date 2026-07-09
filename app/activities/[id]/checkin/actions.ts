"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type RpcError = { code?: string; message?: string; details?: string; hint?: string };

function normalize(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function sanitizedDetail(error: RpcError) {
  const text = [error.message, error.details, error.hint].filter(Boolean).join(" ").replace(/[\r\n\t]+/g, " ").replace(/\s+/g, " ").trim();
  if (!text) return null;
  return text.replace(/eyJ[a-zA-Z0-9._-]+/g, "[valor oculto]").slice(0, 240);
}

function actionStatus(action: "open" | "close" | "regenerate", error: RpcError) {
  const raw = normalize([error.code, error.message, error.details, error.hint].filter(Boolean).join(" "));
  if (error.code === "42501" || /permission|not authorized|row-level|rls|permiso|autorizad/.test(raw)) return action + "-forbidden";
  if (/draft|borrador/.test(raw)) return action + "-draft";
  return action + "-error";
}

function target(activityId: string, status: string, detail?: string | null) {
  const params = new URLSearchParams({ checkin: status });
  if (detail) params.set("checkin_detail", detail);
  return "/activities/" + activityId + "?" + params.toString() + "#attendance-checkin";
}

export async function openAttendanceCheckin(activityId: string) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");
  const { error } = await supabase.rpc("open_activity_attendance_checkin", { target_activity_id: activityId });
  revalidatePath("/activities");
  revalidatePath("/activities/" + activityId);
  redirect(error ? target(activityId, actionStatus("open", error), sanitizedDetail(error)) : target(activityId, "opened"));
}

export async function closeAttendanceCheckin(activityId: string, formData: FormData) {
  if (formData.get("confirmation") !== "confirmed") redirect(target(activityId, "close-error"));
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");
  const { error } = await supabase.rpc("close_activity_attendance_checkin", { target_activity_id: activityId });
  revalidatePath("/activities");
  revalidatePath("/activities/" + activityId);
  redirect(error ? target(activityId, actionStatus("close", error), sanitizedDetail(error)) : target(activityId, "closed"));
}

export async function regenerateAttendanceCheckin(activityId: string, formData: FormData) {
  if (formData.get("confirmation") !== "confirmed") redirect(target(activityId, "regenerate-error"));
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");
  const closeResult = await supabase.rpc("close_activity_attendance_checkin", { target_activity_id: activityId });
  if (closeResult.error) {
    revalidatePath("/activities/" + activityId);
    redirect(target(activityId, actionStatus("regenerate", closeResult.error), sanitizedDetail(closeResult.error)));
  }
  const openResult = await supabase.rpc("open_activity_attendance_checkin", { target_activity_id: activityId });
  revalidatePath("/activities");
  revalidatePath("/activities/" + activityId);
  redirect(openResult.error ? target(activityId, actionStatus("regenerate", openResult.error), sanitizedDetail(openResult.error)) : target(activityId, "regenerated"));
}
