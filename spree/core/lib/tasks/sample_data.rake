namespace :spree do
  desc '[DEPRECATED] Loads nothing: sample data is loaded through the Admin API with `spree sample-data`'
  task load_sample_data: :environment do
    Spree::SampleData::Loader.call
  end
end

# Backwards compatibility
namespace :spree_sample do
  desc '[DEPRECATED] Loads nothing: sample data is loaded through the Admin API with `spree sample-data`'
  task load: :environment do
    Rake::Task['spree:load_sample_data'].invoke
  end
end
