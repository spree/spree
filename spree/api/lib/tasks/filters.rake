namespace :spree do
  namespace :api do
    desc 'Print the filter tables of every list endpoint, as JSON, for `spree filters types`'
    task filter_tables: :environment do
      Rails.application.eager_load!
      apis = %w[store admin seller].index_with { |api| Spree::Api::V3::FilterTable.spec_for(api) }

      # One line: the CLI drops boot noise line by line.
      puts apis.to_json
    end
  end
end
