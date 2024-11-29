# setup default store, to be always present
RSpec.configure do |config|
  config.before(:each) do
    country = create(:country, name: 'United States of America', iso_name: 'UNITED STATES', iso: 'US', iso3: 'USA', states_required: true)
    create(:store, default: true, default_country: country, default_currency: 'USD')
  end
end
