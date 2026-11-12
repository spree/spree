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
          request_params :stock_location do |body|
            body.attribute :name, :string, required: true, on: :create, example: 'Main warehouse'
            body.attribute :admin_name, :string, nullable: true
            body.attribute :active, :boolean, description: 'Set `false` to retire a location: there is no delete.'
            body.attribute :default, :boolean
            body.attribute :kind, :string,
              choices: Spree::StockLocation::KINDS,
              open: true,
              example: 'warehouse',
              description: 'Categorizes the location.'
            body.attribute :propagate_all_variants, :boolean
            body.attribute :backorderable_default, :boolean
            body.attribute :address1, :string, nullable: true
            body.attribute :address2, :string, nullable: true
            body.attribute :city, :string, nullable: true
            body.attribute :zipcode, :string, nullable: true
            body.attribute :phone, :string, nullable: true
            body.attribute :company, :string, nullable: true
            body.attribute :country_code, :country,
              nullable: true,
              example: 'US',
              description: 'ISO-3166 alpha-2 country code.'
            body.attribute :state_code, :string,
              nullable: true,
              example: 'OR',
              description: "State or province abbreviation, resolved against the selected country's states."
            body.attribute :state_name, :string,
              nullable: true,
              description: "Free-text state for countries that don't have a states list."
            body.attribute :pickup_enabled, :boolean
            body.attribute :pickup_stock_policy, :string,
              choices: Spree::StockLocation::PICKUP_STOCK_POLICIES,
              description: '`local` collects only items at this location; `any` lets items transfer in from other locations (ship-to-store).'
            body.attribute :pickup_ready_in_minutes, :integer, nullable: true
            body.attribute :returns_enabled, :boolean,
              description: 'Whether customers may send returns to this location.'
            body.attribute :pickup_instructions, :string, nullable: true
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
