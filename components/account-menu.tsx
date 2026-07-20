"use client";

import Link from "next/link";
import { useEffect, useId, useRef, useState } from "react";
import { logout } from "@/app/dashboard/actions";
import { Avatar } from "@/components/avatar";
import { HomeIcon } from "@/components/home-icon";

export function AccountMenu({ displayName, email, imageUrl, initials, canViewCatalogs, canAdministerAccounts }: {
  displayName: string;
  email: string;
  imageUrl: string | null;
  initials: string;
  canViewCatalogs: boolean;
  canAdministerAccounts: boolean;
}) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const menuId = useId();

  useEffect(() => {
    if (!open) return;
    const dismissOutside = (event: PointerEvent) => {
      if (!containerRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const dismissEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        containerRef.current?.querySelector<HTMLButtonElement>("button")?.focus();
      }
    };
    document.addEventListener("pointerdown", dismissOutside);
    document.addEventListener("keydown", dismissEscape);
    return () => {
      document.removeEventListener("pointerdown", dismissOutside);
      document.removeEventListener("keydown", dismissEscape);
    };
  }, [open]);

  return (
    <div ref={containerRef} className="relative">
      <button type="button" aria-label="Abrir menú de cuenta" aria-haspopup="menu" aria-expanded={open} aria-controls={menuId} onClick={() => setOpen((value) => !value)} className="grid min-h-12 min-w-12 cursor-pointer place-items-center rounded-full transition hover:bg-[var(--sitaa-blue-light)]">
        <Avatar imageUrl={imageUrl} initials={initials} alt={`Foto de perfil de ${displayName}`} />
      </button>
      {open && (
        <div id={menuId} role="menu" className="absolute right-0 z-50 mt-2 w-[min(19rem,calc(100vw-2rem))] rounded-2xl border border-[var(--sitaa-border)] bg-white p-2 shadow-2xl shadow-blue-950/15">
          <div className="min-w-0 border-b border-slate-200 px-3 py-3">
            <p className="truncate font-bold text-[var(--sitaa-text)]">{displayName}</p>
            <p className="sitaa-wrap-anywhere mt-1 text-sm text-[var(--sitaa-text-secondary)]">{email}</p>
          </div>
          <div className="border-b border-slate-200 py-1 lg:hidden">
            <Link href="/dashboard" role="menuitem" onClick={() => setOpen(false)} className="flex min-h-11 cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]"><HomeIcon />Inicio</Link>
            <Link href="/activities" role="menuitem" onClick={() => setOpen(false)} className="flex min-h-11 cursor-pointer items-center rounded-lg px-3 py-2 text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]">Actividades</Link>
            {canViewCatalogs && (
              <Link href="/catalogs" role="menuitem" onClick={() => setOpen(false)} className="flex min-h-11 cursor-pointer items-center rounded-lg px-3 py-2 text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]">Catálogos</Link>
            )}
            {canAdministerAccounts && (
              <Link href="/admin/accounts" role="menuitem" onClick={() => setOpen(false)} className="flex min-h-11 cursor-pointer items-center rounded-lg px-3 py-2 text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]">Cuentas</Link>
            )}
          </div>
          <Link href="/profile" role="menuitem" onClick={() => setOpen(false)} className="mt-1 flex min-h-11 cursor-pointer items-center rounded-lg px-3 py-2 text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]">Mi perfil</Link>
          <form action={logout}>
            <button type="submit" role="menuitem" className="flex min-h-11 w-full cursor-pointer items-center rounded-lg px-3 py-2 text-left text-sm font-bold text-red-700 hover:bg-red-50">Cerrar sesión</button>
          </form>
        </div>
      )}
    </div>
  );
}
