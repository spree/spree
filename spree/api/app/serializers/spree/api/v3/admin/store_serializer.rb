module Spree
  module Api
    module V3
      module Admin
        class StoreSerializer < V3::BaseSerializer
          typelize name: :string, url: :string,
                   default_currency: :string, default_locale: :string,
                   supported_currencies: [:string, multi: true],
                   supported_locales: [:string, multi: true],
                   logo_url: [:string, nullable: true],
                   preferred_admin_locale: [:string, nullable: true],
                   preferred_timezone: :string,
                   preferred_weight_unit: :string,
                   preferred_unit_system: :string,
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     :name,
                     :default_currency,
                     :default_locale,
                     :preferred_admin_locale,
                     :preferred_timezone,
                     :preferred_weight_unit,
                     :preferred_unit_system,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :url, &:storefront_url

          attribute :supported_currencies do |store|
            store.supported_currencies_list.map(&:iso_code)
          end

          attribute :supported_locales, &:supported_locales_list

          attribute :logo_url do |store|
            image_url_for(store.logo)
          end
        end
      end
    end
  end
end
