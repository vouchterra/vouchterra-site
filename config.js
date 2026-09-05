// VouchTerra client config.
// The anon key is a PUBLIC key by design (Supabase row-level security does the real protection).
// Fill these in from Supabase → Project Settings → API. Leave blank until then; pages show a
// "sign-in is being set up" notice instead of erroring.
window.VT_CONFIG = {
  supabaseUrl: "",
  supabaseAnonKey: "",
  foundingLimit: 10
};
