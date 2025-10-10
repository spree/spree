# setup default store, to be always present
RSpec.configure do |config|
  config.before(:suite) do
    if defined?(ActiveSupport::SafeBuffer)
      ActiveSupport::SafeBuffer.class_eval do
        # Make Psych serialize SafeBuffer as a plain string
        def encode_with(coder)
          coder.represent_scalar(nil, to_s)
        end
      end
    end
  end

  config.before(:all) do
    unless self.class.metadata[:without_global_store]
      @default_country = Spree::Country.find_by(iso: 'US') || FactoryBot.create(:country_us)
      @default_store = Spree::Store.find_by(default: true) || FactoryBot.create(:store, default: true, default_country: @default_country, default_currency: 'USD')
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
