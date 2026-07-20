"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { HomeIcon } from "@/components/home-icon";

const links = [
  { href: "/dashboard", label: "Inicio" },
  { href: "/activities", label: "Actividades" },
];

export function AuthenticatedNavigation({
  canViewCatalogs,
  canAdministerAccounts,
}: {
  canViewCatalogs: boolean;
  canAdministerAccounts: boolean;
}) {
  const pathname = usePathname();
  const visibleLinks = [
    ...links,
    ...(canViewCatalogs ? [{ href: "/catalogs", label: "Catálogos" }] : []),
    ...(canAdministerAccounts ? [{ href: "/admin/accounts", label: "Cuentas" }] : []),
  ];

  return (
    <nav aria-label="Navegación principal" className="hidden items-center gap-1 lg:flex">
      {visibleLinks.map((link) => {
        const selected = pathname === link.href || (link.href !== "/dashboard" && pathname.startsWith(`${link.href}/`));
        return (
          <Link
            key={link.href}
            href={link.href}
            aria-current={selected ? "page" : undefined}
            className="sitaa-nav-link"
          >
            {link.href === "/dashboard" && <HomeIcon />}
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
