import type { Metadata } from "next";
import { AuthenticationCard } from "@/components/authentication-card";
import { NodeNetworkBackground } from "@/components/node-network-background";
import { safeNextPath } from "@/lib/navigation/safe-next-path";

export const metadata: Metadata = { title: "Iniciar sesión" };

const errorMessages: Record<string, string> = {
  configuracion: "El acceso no está configurado todavía. Contacta a la persona administradora.",
  credenciales: "No fue posible iniciar sesión. Verifica tu correo y contraseña.",
  "datos-incompletos": "Escribe tu correo y contraseña para continuar.",
  "sesion-requerida": "Inicia sesión para continuar.",
  "verificacion-pendiente": "Confirma tu correo antes de iniciar sesión.",
  google: "No fue posible iniciar sesión con Google. Intenta nuevamente.",
  "google-cancelado": "Se canceló el acceso con Google. Puedes intentarlo nuevamente.",
  "google-cuenta": "Google no pudo crear o vincular la cuenta. Intenta nuevamente.",
  "google-codigo": "La respuesta de Google no incluyó la autorización necesaria.",
  "google-intercambio": "No fue posible completar el intercambio de sesión con Google.",
  "google-sesion": "Google respondió, pero no fue posible recuperar la sesión autenticada.",
  "google-temporal": "Ocurrió un error temporal de autenticación. Intenta nuevamente.",
  "enlace-heredado": "El enlace de acceso heredado no es válido o ya expiró.",
};

type LoginPageProps = { searchParams: Promise<{ error?: string | string[]; next?: string | string[] }> };

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const errorCode = Array.isArray(params.error) ? params.error[0] : params.error;
  const nextPath = safeNextPath(params.next);
  return (
    <section className="relative isolate grid min-h-[calc(100svh-4.5rem)] place-items-center overflow-hidden px-4 py-4 sm:px-6">
      <NodeNetworkBackground />
      <div className="relative z-10 w-full max-w-md">
        <AuthenticationCard errorMessage={errorCode ? errorMessages[errorCode] : undefined} nextPath={nextPath} />
      </div>
    </section>
  );
}
