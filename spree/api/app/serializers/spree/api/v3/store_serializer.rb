module Spree
  module Api
    module V3
      # The current store's public identity, branding and default SEO metadata,
      # in the request's locale. Missing translations fall back to the store's
      # default locale.
      class StoreSerializer < BaseSerializer
        typelize name: :string,
                 seo_title: [:string, nullable: true],
                 meta_description: [:string, nullable: true],
                 meta_keywords: [:string, nullable: true],
                 logo_url: [:string, nullable: true],
                 facebook: [:string, nullable: true, comment: 'Facebook page, as entered by the merchant: a handle or a full URL.'],
                 twitter: [:string, nullable: true, comment: 'X (Twitter) account, as entered by the merchant: a handle or a full URL.'],
                 instagram: [:string, nullable: true, comment: 'Instagram account, as entered by the merchant: a handle or a full URL.'],
                 customer_support_email: [:string, nullable: true],
                 mail_from_address: [:string, nullable: true]

        attributes :name, :seo_title, :meta_description, :meta_keywords,
                   :facebook, :twitter, :instagram,
                   :customer_support_email, :mail_from_address

        attribute :logo_url do |store|
          image_url_for(store.logo)
        end
      end
    end
  end
end
