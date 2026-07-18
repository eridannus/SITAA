import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "SITAA", template: "%s | SITAA" },
  description: "Sistema Integral de Tutorías y Asesorías Académicas.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
