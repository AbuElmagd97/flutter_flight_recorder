/// Metadata keys masked by default, matched case-insensitively at every
/// nesting depth. See [PrivacyConfig.sensitiveKeys] to extend or replace
/// this set.
const Set<String> defaultSensitiveKeys = {
  'password',
  'token',
  'authorization',
  'access_token',
  'refresh_token',
  'cookie',
  'session',
};
