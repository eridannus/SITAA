import type { ReactNode } from "react";

export type StatusTone = "neutral" | "info" | "success" | "warning" | "error";

const toneClass: Record<StatusTone, string> = {
  neutral: "",
  info: "sitaa-status-badge--info",
  success: "sitaa-status-badge--success",
  warning: "sitaa-status-badge--warning",
  error: "sitaa-status-badge--error",
};

export function StatusBadge({ children, tone = "neutral", className = "" }: {
  children: ReactNode;
  tone?: StatusTone;
  className?: string;
}) {
  return <span className={`sitaa-status-badge ${toneClass[tone]} ${className}`.trim()}>{children}</span>;
}
