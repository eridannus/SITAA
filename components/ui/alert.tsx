import type { HTMLAttributes, ReactNode } from "react";
import type { StatusTone } from "@/components/ui/status-badge";

const toneClass: Record<StatusTone, string> = {
  neutral: "",
  info: "sitaa-alert--info",
  success: "sitaa-alert--success",
  warning: "sitaa-alert--warning",
  error: "sitaa-alert--error",
};

export function Alert({ children, tone = "neutral", className = "", ...props }: {
  children: ReactNode;
  tone?: StatusTone;
} & HTMLAttributes<HTMLDivElement>) {
  return <div className={`sitaa-alert ${toneClass[tone]} ${className}`.trim()} {...props}>{children}</div>;
}
