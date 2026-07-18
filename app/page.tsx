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
    <section className="sitaa-public-gateway">
      <NodeNetworkBackground />
      <div className="sitaa-public-card-scroll"><AuthenticationCard /></div>
    </section>
  );
}
