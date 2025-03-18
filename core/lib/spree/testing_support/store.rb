# setup default store, to be always present
RSpec.configure do |config|
  config.before(:all) do
    unless self.class.metadata[:without_global_store]
      @default_country = Spree::Country.find_by(iso: 'US') || FactoryBot.create(:country, name: 'United States of America', iso_name: 'UNITED STATES', iso: 'US', iso3: 'USA', states_required: true)
      @default_store = Spree::Store.find_by(default: true) || FactoryBot.create(:store, default: true, default_country: @default_country, default_currency: 'USD')
    end
  end

  config.before(:each) do
    unless self.class.metadata[:without_global_store]
      allow_any_instance_of(Spree::Store).to receive(:default).and_return(@default_store)
    end
  end

  config.after(:each) do
    unless self.class.metadata[:without_global_store]
      @default_store&.products = []
      @default_store&.promotions = []
      @default_store&.checkout_zone = nil
      @default_store&.payment_methods = []
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
