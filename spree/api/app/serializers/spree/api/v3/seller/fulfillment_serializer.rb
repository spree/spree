module Spree
  module Api
    module V3
      module Seller
        # A parcel this seller owes on one of their orders.
        #
        # Declared rather than subclassed from the store's fulfillment, which
        # nests delivery rates and the store's own stock location serializer —
        # rate selection is a checkout concern, and the location a seller cares
        # about is their own shelf, named here rather than expanded.
        class FulfillmentSerializer < V3::BaseSerializer
          typelize number: :string,
                   status: :string,
                   tracking: [:string, nullable: true],
                   tracking_url: [:string, nullable: true],
                   tracking_carrier: [:string, nullable: true],
                   tracking_status: [:string, nullable: true],
                   fulfillment_type: [:string, nullable: true],
                   delivery_method_name: [:string, nullable: true],
                   stock_location_name: [:string, nullable: true]

          attributes :number, :status, :tracking, :tracking_url, :tracking_carrier,
                     :tracking_status,
                     fulfilled_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

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

          # Deliberately not `items`: the store's fulfillment answers with a
          # manifest under that name, and the shared OpenAPI patch rewrites it
          # to that shape — a seller's rows would be documented as somebody
          # else's. These are the persisted fulfillment items, so they say so.
          many :fulfillment_items,
               resource: proc { Spree.api.seller_fulfillment_item_serializer }
        end
      end
    end
  end
end
