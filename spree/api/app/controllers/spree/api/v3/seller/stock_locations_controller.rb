module Spree
  module Api
    module V3
      module Seller
        # A seller's own stock locations — where their inventory sits and
        # where customer returns are sent.
        #
        # Rooted in `current_seller.stock_locations`, so an id belonging to
        # the operator or to another seller is a 404. That matters more here
        # than on most collections: a stock location is an address a shopper
        # is given, and the operator's warehouse address is not a seller's to
        # read or to hand out.
        #
        # No destroy: a location holds stock levels and is named on historical
        # fulfillments, so removing one is an inventory operation rather than
        # a delete. A seller retires a location by deactivating it.
        class StockLocationsController < Seller::ResourceController
          scoped_resource :stock_locations

          protected

          def model_class
            Spree::StockLocation
          end

          def serializer_class
            Spree.api.seller_stock_location_serializer
          end

          def permitted_params
            params.permit(
              :name, :company, :address1, :address2, :city, :zipcode,
              :country_code, :state_code, :state_name, :phone,
              :active, :default, :kind
            )
          end

          # A new location is this seller's, and its store follows them.
          def build_resource
            current_seller.stock_locations.new(permitted_params.merge(store: current_store))
          end
        end
      end
    end
  end
end
