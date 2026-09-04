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
          # `:stock`, the catalog resource that lists `Spree::StockLocation`
          # among its subjects — there is no `stock_locations` resource, and a
          # name the catalog does not know skips the key gate entirely rather
          # than failing loudly. Writes take `write_stock` here where the
          # operator's twin takes `write_settings`: another seller's warehouse
          # is store-wide administration, but a seller's own is just their
          # stock.
          scoped_resource :stock

          protected

          def model_class
            Spree::StockLocation
          end

          def serializer_class
            Spree.api.seller_stock_location_serializer
          end

          # The same set the operator's controller permits: a seller runs
          # their own warehouse, so every field on the shared form is theirs to
          # set. Anything missing here is dropped by `permit` without a word,
          # and the form would appear to save while quietly discarding it.
          def permitted_params
            params.permit(
              *model_additional_permitted_attributes,
              :name, :admin_name, :active, :default,
              :kind, :propagate_all_variants, :backorderable_default,
              :address1, :address2, :city, :zipcode, :phone, :company,
              :country_code, :state_code, :state_name,
              :pickup_enabled, :pickup_stock_policy, :returns_enabled,
              :pickup_ready_in_minutes, :pickup_instructions
            )
          end
        end
      end
    end
  end
end
