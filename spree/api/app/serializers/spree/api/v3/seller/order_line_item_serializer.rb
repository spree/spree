module Spree
  module Api
    module V3
      module Seller
        # A line on one of this seller's orders — what to pick, how many, and
        # what it sold for.
        #
        # Declared rather than subclassed from the store's line item: that one
        # carries the associations a storefront needs (digital links, tax
        # lines, the seller's own public profile), none of which help someone
        # packing a box, and each of which would pull another serializer into
        # this branch's generated types.
        class OrderLineItemSerializer < V3::BaseSerializer
          typelize name: :string,
                   sku: [:string, nullable: true],
                   options_text: [:string, nullable: true],
                   quantity: :number,
                   currency: :string,
                   variant_id: [:string, nullable: true],
                   thumbnail_url: [:string, nullable: true]

          attributes :name, :options_text, :quantity, :currency

          money_attributes :price, :display_price, :total, :display_total

          attribute :variant_id do |line_item|
            line_item.variant&.prefixed_id
          end

          # How a seller finds the item on their own shelf.
          attribute :sku do |line_item|
            line_item.variant&.sku
          end

          attribute :thumbnail_url do |line_item|
            image_url_for(line_item.thumbnail)
          end
        end
      end
    end
  end
end
