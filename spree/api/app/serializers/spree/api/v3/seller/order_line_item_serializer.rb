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
          typelize name: :string, sku: [:string, nullable: true], options_text: [:string, nullable: true],
                   quantity: :number, currency: :string, variant_id: [:string, nullable: true],
                   thumbnail_url: [:string, nullable: true]

          attributes :name, :options_text, :quantity, :currency

          # The tax charged on top is what a claim refunds beside the goods.
          money_attributes :price, :display_price, unit_price: true
          money_attributes :discounted_amount, :display_discounted_amount,
                           :additional_tax_total, :total, :display_total

          prefixed_id_attributes :variant

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
