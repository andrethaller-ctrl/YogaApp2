import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

    const { data: verifyResult, error: verifyError } = await supabase.rpc(
      "verify_token",
      { p_token: token, p_type: "email_verification" }
    );

    console.log("Verify result:", JSON.stringify(verifyResult));
    console.log("Verify error:", JSON.stringify(verifyError));

    if (verifyError) {
      console.error("Token verification error:", verifyError);
      return new Response(
        JSON.stringify({ type: "verify_error", error: "Fehler bei der Token-Überprüfung", details: verifyError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!verifyResult || verifyResult.length === 0) {
      console.error("No result from verify_token");
      return new Response(
        JSON.stringify({ type: "no_result", error: "Keine Antwort von der Verifizierungsfunktion" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result = verifyResult[0];
    console.log("Result object:", JSON.stringify(result));

    if (!result.valid) {
      return new Response(
        JSON.stringify({ type: "invalid_token", error: result.message || "Token ungültig oder abgelaufen" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = result.user_id;

    if (!userId) {
      console.error("No user_id in result");
      return new Response(
        JSON.stringify({ type: "no_user_id", error: "Keine Benutzer-ID gefunden" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

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
        JSON.stringify({ type: "update_error", error: "Fehler beim Aktualisieren des Benutzerstatus", details: updateError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Marking token as used");

    const { error: markError } = await supabase.rpc("mark_token_used", { p_token: token });
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
      JSON.stringify({ type: "unknown", error: "Ein Fehler ist aufgetreten", details: error.message || String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});