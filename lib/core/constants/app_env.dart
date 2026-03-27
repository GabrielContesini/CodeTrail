class AppEnv {
  const AppEnv._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const billingProvider = String.fromEnvironment(
    'BILLING_PROVIDER',
    defaultValue: 'stripe',
  );
  static const stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );
  static const trialDaysDefault = int.fromEnvironment(
    'TRIAL_DAYS_DEFAULT',
    defaultValue: 7,
  );
  static const foundingPlanEnabled = bool.fromEnvironment(
    'FOUNDING_PLAN_ENABLED',
    defaultValue: true,
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
