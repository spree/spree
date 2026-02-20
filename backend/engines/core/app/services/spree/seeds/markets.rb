module Spree
  module Seeds
    class Markets
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.each do |store|
          next if store.markets.any?

          countries = if store.checkout_zone.present?
                        store.checkout_zone.country_list
                      else
                        Spree::Country.all
                      end
          next unless countries.any?

          store.markets.create!(
            name: 'Default',
            currency: store.default_currency,
            default_locale: store.default_locale || I18n.locale.to_s,
            default: true,
            countries: countries
          )
        end
      end
    end
  end
end
