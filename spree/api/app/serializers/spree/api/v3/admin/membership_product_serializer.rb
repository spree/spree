module Spree
  module Api
    module V3
      module Admin
        # A product as a curating parent's membership card reads it: the row's
        # name and thumbnail, and nothing else.
        #
        # Deliberately not a subclass of the admin product serializer. These
        # endpoints feed one card and the picker's exclusion list, neither of
        # which reads a product's status, media, categories, publications,
        # channels or custom fields — and the pages render a variant row per
        # product, so a full product payload per row is the difference between
        # a card that opens and one that crawls. A field a card starts needing
        # is one line in the subclass that needs it
        # (docs/plans/6.0-volume-pricing.md).
        class MembershipProductSerializer < V3::BaseSerializer
          typelize name: :string, thumbnail_url: [:string, nullable: true]

          attributes :name

          # The card's row image.
          attribute :thumbnail_url do |product|
            image_url_for(product.primary_media)
          end
        end
      end
    end
  end
end
