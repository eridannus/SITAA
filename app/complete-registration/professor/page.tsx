import type { Metadata } from "next";
import { CompletionRegistrationPage } from "@/components/completion-registration-page";

export const metadata: Metadata = { title: "Completar registro de profesor" };

export default function ProfessorCompletionPage() {
  return <CompletionRegistrationPage personType="professor" />;
}
