/// Deployment version identifier.
///
/// Injected at build time by the deployment script:
/// `--dart-define=APP_VERSION=... --dart-define=BUILD_STAMP=...`
/// Defaults keep plain local builds working.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'V1.0.0',
);

const String buildStamp = String.fromEnvironment(
  'BUILD_STAMP',
  defaultValue: 'local-build',
);
