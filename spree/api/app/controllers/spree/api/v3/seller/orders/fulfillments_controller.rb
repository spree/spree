module Spree
  module Api
    module V3
      module Seller
        module Orders
          # The parcels this seller owes on one of their orders.
          #
          # Shipping, cancelling and splitting are the operator's workflows,
          # shared through the concern, so the customer email, the label
          # purchase and the extension hooks all happen exactly as they do
          # when the marketplace ships on the seller's behalf.
          #
          # What is here is what makes them the seller's: the order comes from
          # `current_seller_orders`, so a fulfillment on somebody else's order
          # reads as missing rather than denied, and both the goods that may
          # be split and the shelves they ship from are the seller's own.
          #
          # No `mark_delivered` and no `create`: that goods arrived is the
          # buyer's word rather than the sender's, and a parcel comes into
          # being from the order, not from the seller.
          class FulfillmentsController < BaseController
            include Spree::Api::V3::Orders::FulfillmentActions

            before_action :set_resource, only: [:show, :update, :fulfill, :cancel, :split]

            protected

            def serializer_class
              Spree.api.seller_fulfillment_serializer
            end

            def collection_includes
              [:deliveries, :shipping_labels, :fulfillment_items]
            end

            def permitted_params
              params.permit(:tracking, :tracking_carrier, :stock_location_id,
                            :selected_delivery_rate_id)
            end

            private

            # What may be split out is what this parcel is actually carrying,
            # resolved through the order rather than the catalogue.
            def variant_for_split
              @order.variants.find_by_prefix_id!(params[:variant_id])
            end

            # The seller's own shelves only — defaulting to where this parcel
            # already sits.
            def stock_location_for_split
              return @resource.stock_location if params[:stock_location_id].blank?

              seller_stock_location!(params[:stock_location_id])
            end

            # The workflow assigns the origin raw, so the prefixed id is
            # resolved through the seller's own shelves first — a marketplace
            # warehouse 404s here rather than reaching the assignment.
            def update_attributes
              attributes = permitted_params.to_h

              if permitted_params[:stock_location_id].present?
                attributes['stock_location_id'] =
                  seller_stock_location!(permitted_params[:stock_location_id]).id
              end

              attributes
            end

            def seller_stock_location!(id)
              current_seller.stock_locations.find_by_prefix_id!(id)
            end
          end
        end
      end
    end
  end
end
