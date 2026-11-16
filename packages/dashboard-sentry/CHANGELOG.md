# @spree/dashboard-sentry

## 6.0.5

### Patch Changes

- [#15220](https://github.com/spree/spree/pull/15220) [`f32acce`](https://github.com/spree/spree/commit/f32accecc5873d951cbd5d57a8410aeffd33d7f8) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - New package that reports admin dashboard and seller panel errors to Sentry: call `initDashboardSentry({ dsn })` in the app's entry module, with any other Sentry browser option. Tokens are redacted from every event and breadcrumb it sends.
