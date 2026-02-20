module Spree
  module Seeds
    class Markets
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.each do |store|
          next if store.markets.any?

          zone = store.checkout_zone || Spree::Zone.find_by(name: 'North America') || Spree::Zone.first
          next unless zone

          store.markets.create!(
            name: 'Default',
            currency: store.default_currency,
            default_locale: store.default_locale || I18n.locale.to_s,
            zone: zone,
            default: true
          )
        end
      end
    end
  end
end
