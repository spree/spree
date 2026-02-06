module Spree
  module Api
    module V3
      class StoreSerializer < BaseSerializer
        typelize name: :string, url: :string, meta_description: 'string | null',
                 meta_keywords: 'string | null', seo_title: 'string | null',
                 default_currency: :string, code: :string, default: :boolean,
                 facebook: 'string | null', twitter: 'string | null', instagram: 'string | null',
                 customer_support_email: 'string | null', default_locale: :string,
                 supported_currencies: 'string[]', favicon_image_url: 'string | null',
                 logo_image_url: 'string | null', social_image_url: 'string | null',
                 supported_locales: 'string[]', default_country_iso: 'string | null'

        attributes :name, :url, :meta_description, :meta_keywords, :seo_title,
                   :default_currency, :code, :default, :facebook, :twitter,
                   :instagram, :customer_support_email, :default_locale,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :default_country_iso do |store|
          store.default_country&.iso
        end

        attribute :supported_currencies do |store|
          store.supported_currencies_list.map(&:iso_code)
        end

        attribute :favicon_image_url do |store|
          image_url_for(store.favicon_image)
        end

        attribute :logo_image_url do |store|
          image_url_for(store.logo)
        end

        attribute :social_image_url do |store|
          image_url_for(store.social_image)
        end

        attribute :supported_locales do |store|
          store.supported_locales_list
        end

        many :payment_methods,
             proc { |payment_methods, _params|
               payment_methods.select { |pm| pm.available_on_front_end? && pm.active? }
             },
             resource: Spree.api.payment_method_serializer
      end
    end
  end
end
