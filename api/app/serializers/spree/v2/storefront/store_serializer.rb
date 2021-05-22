module Spree
  module V2
    module Storefront
      class StoreSerializer < BaseSerializer
        set_type :store

        attributes :name, :url, :meta_description, :meta_keywords, :seo_title, :default_currency, :default, :supported_currencies, :facebook,
                   :twitter, :instagram, :default_locale, :customer_support_email, :default_country_id, :description,
                   :address, :contact_phone, :supported_locales

        has_many :menus
        has_one :default_country, serializer: :country, record_type: :country, id_method_name: :default_country_id

        attribute :favicon_path do |store|
          if store.favicon_image.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_representation_path(store.favicon, only_path: true)
          end
        end
      end
    end
  end
end
