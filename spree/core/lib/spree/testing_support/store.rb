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
      # Ensure locale is set to :en before creating store to avoid translation issues
      # when previous tests left the locale in a different language
      I18n.with_locale(:en) do
        Spree::Events.disable do
          @default_country = Spree::Country.find_by(iso: 'US') || FactoryBot.create(:country_us)
          @default_store = Spree::Store.find_by(default: true) || FactoryBot.create(:store, default: true, default_currency: 'USD')
          @default_store.update_column(:default_country_id, @default_country.id) unless @default_store.read_attribute(:default_country_id) == @default_country.id
          @default_market = @default_store.markets.default.first ||
            FactoryBot.create(:market, :default, store: @default_store, countries: [@default_country])
        end
      end
    end
  end

  config.before(:each) do
    unless self.class.metadata[:without_global_store]
      # Reload to clear stale association caches and memoized state from previous tests
      @default_store&.reload
    end
  end

  config.after(:each) do
    unless self.class.metadata[:without_global_store]
      @default_store&.products = []
      @default_store&.promotions = []
      @default_store&.update_column(:checkout_zone_id, nil) if @default_store&.read_attribute(:checkout_zone_id).present?
      @default_store&.payment_methods = []
    end
  end

  config.after(:all) do
    clear_enqueued_jobs
  end
end
