namespace :spree do
  # Plumbing for `spree info` in the CLI, which is how users get the report
  # from the command line, so it has no description and stays out of
  # `bin/rails -T`. The CLI passes what only it can see (Node, Docker,
  # @spree packages) as `{ "title": ..., "rows": { label => value } }`.
  task info: :environment do
    extra_sections = ENV['SPREE_INFO_CLIENT'].present? ? [JSON.parse(ENV['SPREE_INFO_CLIENT']).symbolize_keys] : []
    report = Spree::Diagnostics.report(extra_sections: extra_sections, errors: false)
    puts ENV['FORMAT'] == 'json' ? report.to_h.to_json : report.to_markdown
  end
end
