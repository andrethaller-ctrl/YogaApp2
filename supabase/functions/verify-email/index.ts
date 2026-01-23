import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface VerifyEmailRequest {
  token: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { token }: VerifyEmailRequest = await req.json();

    if (!token) {
      return new Response(
        JSON.stringify({ error: "Token ist erforderlich" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Verifying token:", token.substring(0, 10) + "...");

    const { data: tokenRecord, error: tokenError } = await supabase
      .from("auth_tokens")
      .select("user_id, expires_at, used")
      .eq("token", token)
      .eq("type", "email_verification")
      .maybeSingle();

    console.log("Token record:", JSON.stringify(tokenRecord));
    console.log("Token error:", JSON.stringify(tokenError));

    if (tokenError) {
      console.error("Token lookup error:", tokenError);
      return new Response(
        JSON.stringify({ error: "Fehler bei der Token-Suche", details: tokenError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!tokenRecord) {
      return new Response(
        JSON.stringify({ error: "Token nicht gefunden oder ungültig" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (tokenRecord.used) {
      return new Response(
        JSON.stringify({ error: "Dieser Token wurde bereits verwendet" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const now = new Date();
    const expiresAt = new Date(tokenRecord.expires_at);
    if (expiresAt <= now) {
      return new Response(
        JSON.stringify({ error: "Dieser Token ist abgelaufen" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = tokenRecord.user_id;
    console.log("Updating user:", userId);

    const { error: updateError } = await supabase
      .from("users")
      .update({
        email_verified: true,
        email_verified_at: new Date().toISOString()
      })
      .eq("id", userId);

    if (updateError) {
      console.error("User update error:", updateError);
      return new Response(
        JSON.stringify({ error: "Fehler beim Aktualisieren des Benutzerstatus", details: updateError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Marking token as used");

    const { error: markError } = await supabase
      .from("auth_tokens")
      .update({ used: true })
      .eq("token", token);

    if (markError) {
      console.error("Error marking token as used:", markError);
    }

    console.log("Verification successful");

    return new Response(
      JSON.stringify({ success: true, message: "E-Mail-Adresse erfolgreich bestätigt" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Caught error:", error);
    return new Response(
      JSON.stringify({ error: "Ein Fehler ist aufgetreten", details: error.message || String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
