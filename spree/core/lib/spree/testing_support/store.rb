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
          # Countries are reference data rather than records, so there is
          # nothing to create — the store just names one.
          @default_country = Spree::Country.by_iso('US')
          @default_store = Spree::Store.find_by(default: true) || FactoryBot.create(:store, default: true, default_currency: 'USD')
          unless @default_store.read_attribute(:default_country_code) == 'US'
            @default_store.update_column(:default_country_code, 'US')
          end
        end
      end
    end
  end

  # Reloaded before each example rather than after: the after hooks run
  # inside the example's transaction, so a reload there still sees the
  # example's writes, and the next example would start from values the
  # database no longer holds. Setting a preference to such a stale value is
  # no change to Rails, so it would never be saved.
  config.before(:each) do
    @default_store&.reload unless self.class.metadata[:without_global_store]
  end

  config.after(:each) do
    unless self.class.metadata[:without_global_store]
      @default_store&.products = []
      @default_store&.promotions = []
      @default_store&.update_column(:checkout_zone_id, nil) if @default_store&.read_attribute(:checkout_zone_id).present?
      @default_store&.payment_methods = []
      # The shared +@default_store+ Ruby object lives across the whole
      # +before(:all)+ block, so AR association caches (+default_market+,
      # +channels+, etc.) and per-instance memos (+@has_markets+) need to
      # be cleared between examples or stale +nil+s leak across tests.
      if @default_store
        @default_store.association(:default_market).reset if @default_store.association_cached?(:default_market)
        @default_store.association(:markets).reset if @default_store.association_cached?(:markets)
        @default_store.remove_instance_variable(:@has_markets) if @default_store.instance_variable_defined?(:@has_markets)
      end
    end
  end

  config.after(:all) do
    clear_enqueued_jobs
  end
end
