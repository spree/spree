export function rootPackageJsonContent(name: string): string {
  const pkg = {
    name,
    private: true,
    scripts: {
      dev: 'spree dev',
      stop: 'spree stop',
      down: 'docker compose down',
      update: 'spree update',
      eject: 'spree eject',
      logs: 'spree logs',
      'logs:worker': 'spree logs worker',
      seed: 'spree seed',
      'load-sample-data': 'spree sample-data',
      console: 'spree console',
      api: 'spree api',
      auth: 'spree auth',
      'api-key': 'spree api-key',
    },
    dependencies: {
      // The floor matches the CLI behavior this scaffold relies on (the
      // --quiet delegation, dev co-run, first-run setup) — an older resolve
      // would reject the flags and silently drop the dashboard phase.
      // SPREE_CLI_VERSION overrides the spec for testing unreleased CLIs —
      // a range, or a `file:`/`link:` path to a packed tarball / checkout
      // (mirrors the starter Dockerfile's ARG of the same name).
      '@spree/cli': process.env.SPREE_CLI_VERSION ?? '^2.4.4',
      '@spree/docs': 'latest',
    },
  }

  return `${JSON.stringify(pkg, null, 2)}\n`
}
