{{flutter_js}}
{{flutter_build_config}}

// A distinct URL lets existing service-worker clients load this repaired build.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath += '?release=0.2.9';
  }
}
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
