export function rootPackageJsonContent(name: string): string {
  const pkg = {
    name,
    private: true,
    scripts: {
      dev: 'docker compose up -d',
      down: 'docker compose down',
      logs: 'docker compose logs -f spree',
      'seed': 'docker compose exec spree bin/rails db:seed',
      'load-sample-data': 'docker compose exec spree bin/rails spree:load_sample_data',
      console: 'docker compose exec spree bin/rails c',
    },
  }

  return JSON.stringify(pkg, null, 2) + '\n'
}
