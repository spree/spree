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

          # The same set the operator's controller permits: a seller runs
          # their own warehouse, so every field on the shared form is theirs to
          # set. Anything missing here is dropped by `permit` without a word,
          # and the form would appear to save while quietly discarding it.
          request_params 'StockLocationParams' do
            string :name, example: 'Main warehouse'
            string :admin_name, nullable: true
            boolean :active, description: 'Set `false` to retire a location: there is no delete.'
            boolean :default
            string :kind, example: 'warehouse',
                          description: "Categorizes the location. Built-in values: #{Spree::StockLocation::KINDS.map { |kind| "`#{kind}`" }.join(', ')}; extensions may add their own."
            boolean :propagate_all_variants, :backorderable_default
            string :address1, :address2, :city, :zipcode, :phone, :company, nullable: true
            string :country_code, nullable: true, example: 'US', description: 'ISO-3166 alpha-2 country code.'
            string :state_code, nullable: true, example: 'OR',
                                description: "State or province abbreviation, resolved against the selected country's states."
            string :state_name, nullable: true, description: "Free-text state for countries that don't have a states list."
            boolean :pickup_enabled
            string :pickup_stock_policy, enum: Spree::StockLocation::PICKUP_STOCK_POLICIES,
                                         description: '`local` collects only items at this location; `any` lets items transfer in from other locations (ship-to-store).'
            integer :pickup_ready_in_minutes, nullable: true
            boolean :returns_enabled, description: 'Whether customers may send returns to this location.'
            string :pickup_instructions, nullable: true
          end

          protected

          def model_class
            Spree::StockLocation
          end

          def serializer_class
            Spree.api.seller_stock_location_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
