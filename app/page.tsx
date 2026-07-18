import { redirect } from "next/navigation";
import { AuthenticationCard } from "@/components/authentication-card";
import { NodeNetworkBackground } from "@/components/node-network-background";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (user) redirect("/dashboard");

  return (
    <section className="relative isolate grid min-h-[calc(100svh-4.5rem)] place-items-center overflow-hidden px-4 py-4 sm:px-6">
      <NodeNetworkBackground />
      <div className="relative z-10 w-full max-w-md"><AuthenticationCard /></div>
    </section>
  );
}
