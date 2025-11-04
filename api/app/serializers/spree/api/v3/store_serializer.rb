module Spree
  module Api
    module V3
      class StoreSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            name: resource.name,
            url: resource.url,
            meta_description: resource.meta_description,
            meta_keywords: resource.meta_keywords,
            seo_title: resource.seo_title,
            default_currency: resource.default_currency,
            code: resource.code,
            default: resource.default,
            supported_currencies: resource.supported_currencies_list.map(&:iso_code),
            facebook: resource.facebook,
            twitter: resource.twitter,
            instagram: resource.instagram,
            customer_support_email: resource.customer_support_email,
            default_locale: resource.default_locale,
            supported_locales: resource.supported_locales_list,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
