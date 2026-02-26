export function rootPackageJsonContent(name: string): string {
  const pkg = {
    name,
    private: true,
    scripts: {
      dev: 'docker compose up -d',
      stop: 'docker compose stop',
      down: 'docker compose down',
      logs: 'docker compose logs -f web',
      'logs:worker': 'docker compose logs -f worker',
      'seed': 'docker compose exec web bin/rails db:seed',
      'load-sample-data': 'docker compose exec web bin/rails spree:load_sample_data',
      console: 'docker compose exec web bin/rails c',
    },
  }

  return JSON.stringify(pkg, null, 2) + '\n'
}
