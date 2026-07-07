module Spree
  module Api
    module V3
      # Store API Store Serializer
      # Customer-visible store branding/config — no timestamps, no internal
      # state (mail settings, notification addresses, admin preferences).
      # Admin::StoreSerializer extends this with the back-office fields.
      class StoreSerializer < BaseSerializer
        typelize name: :string, url: :string,
                 default_currency: :string, default_locale: :string,
                 supported_currencies: [:string, multi: true],
                 supported_locales: [:string, multi: true],
                 logo_url: [:string, nullable: true]

        attributes :name, :default_currency, :default_locale

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
