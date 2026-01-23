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

    # Create store ONCE for entire suite (before any tests run)
    I18n.with_locale(:en) do
      Spree::Events.disable do
        @global_default_country = Spree::Country.find_by(iso: 'US') || FactoryBot.create(:country_us)
        @global_default_store = FactoryBot.create(:store, default: true, default_country: @global_default_country, default_currency: 'USD')
      end
    end
  end

  config.before(:all) do
    unless self.class.metadata[:without_global_store]
      # Reference the global objects created in before(:suite)
      # These are recreated by transactional fixtures rollback, so we need to find them
      I18n.with_locale(:en) do
        Spree::Events.disable do
          @default_country = Spree::Country.find_by(iso: 'US') || FactoryBot.create(:country_us)
          @default_store = Spree::Store.find_by(default: true) || FactoryBot.create(:store, default: true, default_country: @default_country, default_currency: 'USD')
        end
      end
    end
  end

  # No after(:each) cleanup needed - transactional fixtures handle rollback automatically

  config.after(:all) do
    unless self.class.metadata[:without_global_store]
      clear_enqueued_jobs
    end
  end
end
