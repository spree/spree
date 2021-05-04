module Spree
  module Api
    module V2
      module Platform
        class StoreSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          attributes :name, :url, :meta_description, :meta_keywords, :seo_title, :default_currency, :default, :supported_currencies, :facebook,
                     :twitter, :instagram, :default_locale, :customer_support_email, :default_country_id, :description,
                     :address, :contact_phone, :supported_locales

          has_many :menus
          has_one :default_country, serializer: :country, record_type: :country, id_method_name: :default_country_id
        end
      end
    end
  end
end
