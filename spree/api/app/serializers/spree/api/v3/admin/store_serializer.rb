module Spree
  module Api
    module V3
      module Admin
        class StoreSerializer < V3::BaseSerializer
          typelize name: :string, url: :string,
                   default_currency: :string, default_locale: :string,
                   supported_currencies: [:string, multi: true],
                   supported_locales: [:string, multi: true],
                   available_locales: [:string, multi: true],
                   logo_url: [:string, nullable: true],
                   mailer_logo_url: [:string, nullable: true],
                   mail_from_address: [:string, nullable: true],
                   customer_support_email: [:string, nullable: true],
                   new_order_notifications_email: [:string, nullable: true],
                   preferred_send_consumer_transactional_emails: :boolean,
                   preferred_admin_locale: [:string, nullable: true],
                   preferred_timezone: :string,
                   preferred_weight_unit: :string,
                   preferred_unit_system: :string,
                   preferred_storefront_access: :string,
                   preferred_guest_checkout: :boolean,
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     :name,
                     :default_currency,
                     :default_locale,
                     :mail_from_address,
                     :customer_support_email,
                     :new_order_notifications_email,
                     :preferred_send_consumer_transactional_emails,
                     :preferred_admin_locale,
                     :preferred_timezone,
                     :preferred_weight_unit,
                     :preferred_unit_system,
                     :preferred_storefront_access,
                     :preferred_guest_checkout,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :url, &:storefront_url

          attribute :supported_currencies do |store|
            store.supported_currencies_list.map(&:iso_code)
          end

          attribute :supported_locales, &:supported_locales_list

          # Canonical set of locales a merchant may translate content into,
          # independent of the store's currently-configured locales. Identical
          # for every store, so the locale pickers can offer the full list
          # rather than only locales already in use (avoids a chicken-and-egg
          # where a new locale can never be added). See `Spree::Locales::ALL`.
          attribute :available_locales do
            Spree::Locales::ALL
          end

          attribute :logo_url do |store|
            image_url_for(store.logo)
          end

          attribute :mailer_logo_url do |store|
            image_url_for(store.mailer_logo)
          end
        end
      end
    end
  end
end
