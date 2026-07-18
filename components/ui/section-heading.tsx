import type { ReactNode } from "react";

export function SectionHeading({ eyebrow, title, description, level = 1, className = "" }: {
  eyebrow?: string;
  title: ReactNode;
  description?: ReactNode;
  level?: 1 | 2 | 3;
  className?: string;
}) {
  const Heading = level === 1 ? "h1" : level === 2 ? "h2" : "h3";
  return (
    <div className={className}>
      {eyebrow && <p className="sitaa-section-eyebrow">{eyebrow}</p>}
      <Heading className="sitaa-section-title mt-2 text-3xl sm:text-4xl">{title}</Heading>
      {description && <p className="sitaa-section-description mt-3">{description}</p>}
    </div>
  );
}
