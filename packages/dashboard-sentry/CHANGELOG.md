# @spree/dashboard-sentry

## 6.0.6

### Patch Changes

- [#15236](https://github.com/spree/spree/pull/15236) [`321d9f0`](https://github.com/spree/spree/commit/321d9f0b0d00e71e0354a686b1dcf2a95d99bd54) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `@spree/dashboard-sentry` now ships its `CHANGELOG.md`, so what changed in the installed version can be read in `node_modules/@spree/dashboard-sentry/`.

## 6.0.5

### Patch Changes

- [#15220](https://github.com/spree/spree/pull/15220) [`f32acce`](https://github.com/spree/spree/commit/f32accecc5873d951cbd5d57a8410aeffd33d7f8) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - New package that reports admin dashboard and seller panel errors to Sentry: call `initDashboardSentry({ dsn })` in the app's entry module, with any other Sentry browser option. It redacts the single-use tokens that travel in URLs (`token=` parameters and password reset paths) from every event and breadcrumb it sends; it does not scrub `Authorization` headers or other credentials.
