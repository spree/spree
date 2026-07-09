module Spree
  module Api
    module V3
      # Store (customer-facing) collection serializer. Deliberately omits the
      # merchandising config — automatic / rules_match_policy / rules — which is
      # back-office state exposed only by the Admin serializer.
      class CollectionSerializer < BaseSerializer
        typelize name: :string, permalink: :string, position: :number,
                 sort_order: :string, hide_from_nav: :boolean,
                 meta_title: [:string, nullable: true], meta_description: [:string, nullable: true], meta_keywords: [:string, nullable: true],
                 description: :string, description_html: :string,
                 image_url: [:string, nullable: true], square_image_url: [:string, nullable: true],
                 products_count: :number

        attributes :name, :permalink, :position, :sort_order, :hide_from_nav,
                   :meta_title, :meta_description, :meta_keywords, :products_count

        attribute :description do |collection|
          collection.description&.to_plain_text.to_s
        end

        attribute :description_html do |collection|
          collection.description&.body&.to_s.to_s
        end

        attribute :image_url do |collection|
          image_url_for(collection.image)
        end

        attribute :square_image_url do |collection|
          image_url_for(collection.square_image)
        end

        many :public_metafields,
             key: :custom_fields,
             resource: proc { Spree.api.custom_field_serializer },
             if: proc { expand?('custom_fields') }
      end
    end
  end
end
