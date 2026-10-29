module Spree
  module Api
    module V3
      # The current store's public identity and default SEO metadata, in the
      # request's locale. Missing translations fall back to the store's default
      # locale.
      class StoreSerializer < BaseSerializer
        typelize name: :string,
                 seo_title: [:string, nullable: true],
                 meta_description: [:string, nullable: true]

        attributes :name, :seo_title, :meta_description
      end
    end
  end
end
