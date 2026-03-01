export function rootPackageJsonContent(name: string): string {
  const pkg = {
    name,
    private: true,
    scripts: {
      dev: 'spree dev',
      stop: 'spree stop',
      down: 'docker compose down',
      update: 'spree update',
      logs: 'spree logs',
      'logs:worker': 'spree logs worker',
      seed: 'spree seed',
      'load-sample-data': 'spree sample-data',
      console: 'spree console',
    },
    dependencies: {
      '@spree/cli': '^0.1.0',
    },
  }

  return JSON.stringify(pkg, null, 2) + '\n'
}
