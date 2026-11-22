// Konfiguration des Partner-Portals.
// URL und "anon public" Key stammen aus Supabase → Project Settings → API.
// Der anon-Key ist für den Browser gedacht und darf öffentlich sein;
// geschützt werden die Daten durch die Zugriffsregeln in setup.sql.
window.PORTAL_CONFIG = {
  SUPABASE_URL: "__SUPABASE_URL__",
  SUPABASE_ANON_KEY: "__SUPABASE_ANON_KEY__",
  BRAND_NAME: "Fidrum Finance",
  BRAND_SHORT: "FF",
  PORTAL_TITLE: "Rechner-Bibliothek für Partner",
  CONTACT_EMAIL: "finanzberatung@daniel-dinh.de",
  CATEGORIES: ["Vermögen aufbauen", "Immobilie als Kapitalanlage", "Für Ihr Kind vorsorgen", "Richtig absichern"]
};
