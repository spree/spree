namespace :spree do
  desc 'Print an anonymised diagnostics report to paste into a bug report (FORMAT=json for JSON)'
  task info: :environment do
    # The CLI passes what only it can see (Node, Docker, @spree packages) as
    # `{ "title": ..., "rows": { label => value } }`.
    extra_sections = ENV['SPREE_INFO_CLIENT'].present? ? [JSON.parse(ENV['SPREE_INFO_CLIENT']).symbolize_keys] : []
    report = Spree::Diagnostics.report(extra_sections: extra_sections, errors: false)
    puts ENV['FORMAT'] == 'json' ? report.to_h.to_json : report.to_markdown
  end
end
