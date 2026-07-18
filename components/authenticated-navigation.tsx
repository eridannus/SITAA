"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/dashboard", label: "Panel" },
  { href: "/activities", label: "Actividades" },
  { href: "/catalogs", label: "Catálogos" },
];

export function AuthenticatedNavigation() {
  const pathname = usePathname();
  return (
    <nav aria-label="Navegación principal" className="hidden items-center gap-1 lg:flex">
      {links.map((link) => {
        const selected = pathname === link.href || (link.href !== "/dashboard" && pathname.startsWith(`${link.href}/`));
        return <Link key={link.href} href={link.href} aria-current={selected ? "page" : undefined} className={`min-h-11 cursor-pointer rounded-lg px-4 py-2.5 text-sm font-bold transition ${selected ? "bg-[var(--sitaa-blue)] text-white shadow-sm" : "text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]"}`}>{link.label}</Link>;
      })}
    </nav>
  );
}
