module Spree
  module Api
    module V3
      module Seller
        # A parcel this seller owes on one of their orders.
        #
        # Declared rather than subclassed from the store's fulfillment, whose
        # stock location serializer is the store's own — the location a seller
        # cares about is their own shelf, named here rather than expanded.
        #
        # The delivery rates quoted for this parcel are here, because a seller
        # picking from a different shelf needs to see what that origin can be
        # carried by. A rate carries only its name and its price, so nothing
        # about the operator's arrangements comes with it.
        class FulfillmentSerializer < V3::BaseSerializer
          typelize number: :string,
                   status: :string,
                   tracking: [:string, nullable: true],
                   tracking_url: [:string, nullable: true],
                   fulfillment_type: [:string, nullable: true],
                   delivery_method_name: [:string, nullable: true],
                   stock_location_name: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true],
                   selected_delivery_rate_id: [:string, nullable: true]

          attributes :number, :status, :tracking, :tracking_url,
                     fulfilled_at: :iso8601, delivered_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          typelize delivered_at: [:string, nullable: true]

          # Null until the parcel actually ships, which is most of its life.
          typelize fulfilled_at: [:string, nullable: true]

          attribute :fulfillment_type do |fulfillment|
            fulfillment.fulfillment_type.presence || (fulfillment.digital? ? 'digital' : 'shipping')
          end

          # How it travels and where it leaves from, as names rather than
          # expanded records: a seller reads them, never edits them here.
          attribute :delivery_method_name do |fulfillment|
            fulfillment.delivery_method&.name
          end

          attribute :stock_location_name do |fulfillment|
            fulfillment.stock_location&.name
          end

          # The id as well as the name, so a seller moving the parcel to
          # another of their shelves can see which one it is on now.
          attribute :stock_location_id do |fulfillment|
            fulfillment.stock_location&.prefixed_id
          end

          # Deliberately not `items`: the store's fulfillment answers with a
          # manifest under that name, and the shared OpenAPI patch rewrites it
          # to that shape — a seller's rows would be documented as somebody
          # else's. These are the persisted fulfillment items, so they say so.
          many :fulfillment_items,
               resource: proc { Spree.api.seller_fulfillment_item_serializer }

          # The consignments and labels on this parcel — what a seller adds
          # when they ship it themselves.
          attribute :selected_delivery_rate_id do |fulfillment|
            fulfillment.selected_delivery_rate&.prefixed_id
          end

          # What this parcel could be carried by from where it currently sits.
          many :delivery_rates, resource: proc { Spree.api.seller_delivery_rate_serializer }

          many :deliveries, resource: proc { Spree.api.seller_delivery_serializer }
          many :shipping_labels, key: :labels, resource: proc { Spree.api.seller_shipping_label_serializer }
        end
      end
    end
  end
end
