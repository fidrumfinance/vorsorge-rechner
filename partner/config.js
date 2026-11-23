// Konfiguration des Partner-Portals.
// URL und "anon public" Key stammen aus Supabase → Project Settings → API.
// Der anon-Key ist für den Browser gedacht und darf öffentlich sein;
// geschützt werden die Daten durch die Zugriffsregeln in setup.sql.
window.PORTAL_CONFIG = {
  SUPABASE_URL: "https://pjhsbjswyoxppdbogujj.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBqaHNianN3eW94cHBkYm9ndWpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUzNjMyNTksImV4cCI6MjExMDkzOTI1OX0.lxKDL5BS8If4j45fwtRCdCx6GBlxNVR6OjHzocCtiuo",
  BRAND_NAME: "Fidrum Finance",
  BRAND_SHORT: "FF",
  PORTAL_TITLE: "Partner-Bibliothek",
  CONTACT_EMAIL: "info@fidrumfinance.com",
  CATEGORIES: ["Vermögen aufbauen", "Immobilie als Kapitalanlage", "Für Ihr Kind vorsorgen", "Richtig absichern"]
};
