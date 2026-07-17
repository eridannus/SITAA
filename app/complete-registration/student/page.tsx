import type { Metadata } from "next";
import { CompletionRegistrationPage } from "@/components/completion-registration-page";

export const metadata: Metadata = { title: "Completar registro de alumno" };

export default function StudentCompletionPage() {
  return <CompletionRegistrationPage personType="student" />;
}
