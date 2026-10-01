namespace :spree do
  desc 'Loads sample data (products, customers, orders, configuration). Set STORE_ID (prefixed or numeric) or STORE_CODE to target a store other than the default one'
  task load_sample_data: :environment do
    store = if ENV['STORE_ID'].present?
              Spree::Store.find_by_param!(ENV['STORE_ID'])
            elsif ENV['STORE_CODE'].present?
              Spree::Store.find_by!(code: ENV['STORE_CODE'])
            end

    Spree::SampleData::Loader.call(store: store)
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
