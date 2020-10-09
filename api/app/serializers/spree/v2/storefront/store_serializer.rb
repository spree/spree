module Spree
  module V2
    module Storefront
      class StoreSerializer < BaseSerializer
        set_type :store

        attributes :name, :url, :meta_description, :meta_keywords, :seo_title, :default_currency, :default, :supported_currencies, :facebook,
                   :twitter, :instagram, :default_locale, :customer_support_email, :default_country_id, :description,
                   :address, :contact_phone, :contact_email
      end
    end
  end
end
