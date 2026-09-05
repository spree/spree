module Spree
  module Api
    module V3
      module Seller
        module Orders
          # The consignments on a parcel the seller ships themselves.
          #
          # CRUD is shared with the operator's branch through the concern.
          # What is here is what makes it the seller's: the order comes from
          # `current_seller_orders`, so a fulfillment on somebody else's order
          # reads as missing rather than denied.
          #
          # No `mark_delivered`: that a parcel arrived is the buyer's word,
          # not the sender's, so confirming receipt stays with the operator
          # and the carrier feed.
          class DeliveriesController < BaseController
            include Spree::Api::V3::Orders::DeliveryActions

            before_action :set_resource, only: [:show, :update, :destroy]

            protected

            def serializer_class
              Spree.api.seller_delivery_serializer
            end

            # The labels and consignments hang off the fulfillment, not the
            # order, so the parent is narrowed one step past the base's.
            def set_parent
              super
              @parent = @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
            end
          end
        end
      end
    end
  end
end
