# setup default store, to be always present
RSpec.configure do |config|
  config.before(:all) do
    unless self.class.metadata[:without_global_store]
      @default_country = FactoryBot.create(:country, name: 'United States of America', iso_name: 'UNITED STATES', iso: 'US', iso3: 'USA', states_required: true)
      @default_store = FactoryBot.create(:store, default: true, default_country: @default_country, default_currency: 'USD')
    end
  end

  config.after(:each) do
    unless self.class.metadata[:without_global_store]
      @default_store&.products = []
    end
  end

  config.after(:all) do
    unless self.class.metadata[:without_global_store]
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
      clear_enqueued_jobs
    end
  end
end
