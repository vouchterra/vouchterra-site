// VouchTerra client config.
// The publishable (anon) key is a PUBLIC key by design — Supabase row-level security does the real protection.
// The secret/service_role key must NEVER go in this repo.
window.VT_CONFIG = {
  supabaseUrl: "https://qkllltrsylsmhphqpyro.supabase.co",
  supabaseAnonKey: "sb_publishable_Y_jcPjH_YC1Nn7dSkD02iQ_3Zv5HtfG",
  foundingLimit: 10
};
