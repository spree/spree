module Spree
  module Api
    module V3
      class StoreSerializer < BaseSerializer
        attributes :id, :name, :url, :meta_description, :meta_keywords, :seo_title,
                   :default_currency, :code, :default, :facebook, :twitter,
                   :instagram, :customer_support_email, :default_locale

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
             resource: Spree.api.v3_storefront_payment_method_serializer
      end
    end
  end
end
