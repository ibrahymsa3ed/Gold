/// Build-time flavor: pass `--dart-define=INSTAGOLD_FLAVOR=dev` or `prod`.
/// Defaults to `prod` so release Play builds do not need an extra flag if you rely on Gradle flavor only.
/// For consistent Dart + Android behavior, scripts pass `INSTAGOLD_FLAVOR` to match `--flavor`.
enum InstaGoldFlavor {
  dev,
  prod,
}

const String _kFlavorRaw = String.fromEnvironment(
  'INSTAGOLD_FLAVOR',
  defaultValue: 'prod',
);

InstaGoldFlavor get instaGoldFlavor {
  switch (_kFlavorRaw) {
    case 'dev':
      return InstaGoldFlavor.dev;
    default:
      return InstaGoldFlavor.prod;
  }
}
