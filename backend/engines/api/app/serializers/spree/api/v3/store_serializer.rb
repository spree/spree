module Spree
  module Api
    module V3
      class StoreSerializer < BaseSerializer
        typelize name: :string, url: :string, meta_description: [:string, nullable: true],
                 meta_keywords: [:string, nullable: true], seo_title: [:string, nullable: true],
                 code: :string,
                 facebook: [:string, nullable: true], twitter: [:string, nullable: true], instagram: [:string, nullable: true],
                 customer_support_email: [:string, nullable: true],
                 favicon_image_url: [:string, nullable: true],
                 logo_image_url: [:string, nullable: true], social_image_url: [:string, nullable: true]

        attributes :name, :url, :meta_description, :meta_keywords, :seo_title,
                   :code, :facebook, :twitter,
                   :instagram, :customer_support_email,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :favicon_image_url do |store|
          image_url_for(store.favicon_image)
        end

        attribute :logo_image_url do |store|
          image_url_for(store.logo)
        end

        attribute :social_image_url do |store|
          image_url_for(store.social_image)
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
