# setup default store, to be always present
RSpec.configure do |config|
  config.before(:all) do
    @default_country = FactoryBot.create(:country, name: 'United States of America', iso_name: 'UNITED STATES', iso: 'US', iso3: 'USA', states_required: true)
    @default_store = FactoryBot.create(:store, default: true, default_country: @default_country, default_currency: 'USD')
  end

  config.after(:each) do
    @default_store.products = []
  end

  config.after(:all) do
    @default_store&.destroy
    @default_country&.destroy
    clear_enqueued_jobs
  end
end
