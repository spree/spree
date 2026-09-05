module Spree
  module Api
    module V3
      module Seller
        # One line inside a parcel: what to pick and how many.
        #
        # Two ids, because the two things a seller does with a parcel address
        # its contents differently: a partial dispatch names line items, and
        # splitting names the variant being moved.
        class FulfillmentItemSerializer < V3::BaseSerializer
          typelize quantity: :number,
                   line_item_id: [:string, nullable: true],
                   variant_id: [:string, nullable: true],
                   name: [:string, nullable: true],
                   sku: [:string, nullable: true],
                   options_text: [:string, nullable: true]

          attributes :quantity

          attribute :line_item_id do |item|
            item.line_item&.prefixed_id
          end

          attribute :variant_id do |item|
            item.variant&.prefixed_id
          end

          attribute :name do |item|
            item.line_item&.name
          end

          attribute :sku do |item|
            item.variant&.sku
          end

          attribute :options_text do |item|
            item.line_item&.options_text
          end
        end
      end
    end
  end
end
