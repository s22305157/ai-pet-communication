# Security regression tests

Requirements: Node.js 22 and Java 21. These tests use only the Firebase emulators
with project `demo-pawlink-security`. Do not replace this ID with a live project.

From this directory:

```sh
npm ci --ignore-scripts
npm run security:patch
npm test
```

The suite loads the repository's current Firestore and Storage rules. It checks
anonymous/cross-account access, protected user fields, invalid document shapes,
pet deletion markers, account deletion markers, and Storage ownership/type/size.
The Storage rules use Firestore lookups; both emulators must be running.

## Version-locked security backports (2026-09-08)

Firebase CLI 15.29.0 still declares stream-json 1.x and Pub/Sub 5.x. The npm
registry has Pub/Sub 6.0.1 with OpenTelemetry 2.8+, but this is outside the CLI's
supported dependency range. We retain the tested CLI API and pin its Pub/Sub
5.3.1 and stream-json 1.9.1 dependencies instead of overriding across major versions.

`patches/manifest.json` contains reviewable before/after edits, exact versions,
and SHA-256 fingerprints. `apply-security-patches.cjs` validates all targets
before changing any files, accepts already-patched content, and fails on drift.
The patch does not change package version numbers or suppress npm advisories.

- **GHSA-528h-pc64-c93x:** backport the upstream filter depth bound (1024) to
  stream-json 1.9.1's shared FilterBase, before path construction. Deep input is
  rejected with a stream error. The CommonJS filter/streamer API is preserved.
- **GHSA-8988-4f7v-96qf:** backport bounded baggage extraction to OpenTelemetry
  core 1.30.1, in its CommonJS, ESM and ESNext builds. Avoid unbounded `join` and
  `split` allocations; accept at most 180 entries, 4096 characters per entry and
  8192 total including separators, matching upstream's encoded-header counting.
  Preserve valid metadata and skip malformed URI encodings. This is an adapted
  backport, not an upstream 1.x release.

Sources (upstream licenses remain in the original dependency files):

- https://github.com/uhop/stream-json/security/advisories/GHSA-528h-pc64-c93x
- https://github.com/uhop/stream-json/blob/master/src/core/filters/filter-base.js
- https://github.com/open-telemetry/opentelemetry-js/security/advisories/GHSA-8988-4f7v-96qf
- https://github.com/open-telemetry/opentelemetry-js/blob/main/packages/opentelemetry-core/src/baggage/utils.ts

Normal installs run `postinstall`; installs with `--ignore-scripts` must run
`npm run security:patch` explicitly. `npm test` also runs the patch verification
and adversarial dependency tests before starting any emulator. Direct invocation
of a newly installed Firebase binary bypasses this protection: apply the patch
first. CI explicitly performs the same step even with lifecycle scripts disabled.

`npm run test:dependencies` runs only the backport regression tests. They exercise
all four JSON filters, normal JSON behavior, oversized and multiple baggage
headers, boundary sizes, malformed input, reproducible application, and rejection
of unexpected dependency contents. No production Firebase credentials are used.

`npm audit` can still report **4 Moderate affected packages** because the upstream
versions retain their advisory ranges. Do not describe this as zero audit findings.
After an upstream CLI release adopts compatible fixes, remove the corresponding
manifest entries and overrides, regenerate the lockfile, and rerun both dependency
and full emulator tests. Do not run `npm audit fix --force` to downgrade the CLI.

The backend's actual handlers also have isolated transaction/failure tests:

```sh
cd ../../functions
npm ci --ignore-scripts
npm run lint
npm test
npm audit --omit=dev
```

Deploy Firestore and Storage rules together with the account handler changes.
Storage's cross-service Firestore access must be enabled during deployment.
Deployment is intentionally separate from these local tests.
