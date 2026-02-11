namespace :spree do
  desc 'Loads sample data (products, customers, orders, configuration)'
  task load_sample_data: :environment do
    Spree::SampleData::Loader.call
  end
end

# Backwards compatibility
namespace :spree_sample do
  desc '[DEPRECATED] Use spree:load_sample_data instead'
  task load: :environment do
    warn '[DEPRECATION] `rake spree_sample:load` is deprecated. Use `rake spree:load_sample_data` instead.'
    Rake::Task['spree:load_sample_data'].invoke
  end
end
