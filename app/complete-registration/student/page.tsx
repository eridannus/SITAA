import type { Metadata } from "next";
import { CompletionRegistrationPage } from "@/components/completion-registration-page";

export const metadata: Metadata = { title: "Completar registro de alumno" };
export const dynamic = "force-dynamic";

export default function StudentCompletionPage() {
  return <CompletionRegistrationPage personType="student" />;
}
