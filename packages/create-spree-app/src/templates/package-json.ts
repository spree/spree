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
    },
    dependencies: {
      '@spree/cli': '^2.0.0',
      '@spree/docs': 'latest',
    },
  }

  return JSON.stringify(pkg, null, 2) + '\n'
}
