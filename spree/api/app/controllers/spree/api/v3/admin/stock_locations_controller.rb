module Spree
  module Api
    module V3
      module Admin
        class StockLocationsController < ResourceController
          scoped_resource :stock

          request_params :stock_location do
            external_references
            string :name, required: :create, example: 'Brooklyn warehouse'
            string :admin_name, nullable: true, description: 'Internal name shown only in the admin.'
            boolean :active
            boolean :default, description: 'Setting to true demotes the previous default.'
            string :kind, enum: Spree::StockLocation::KINDS, open: true, example: 'warehouse',
                          description: 'Categorizes the location.'
            boolean :propagate_all_variants, :backorderable_default
            string :address1, :address2, :city, :zipcode, :phone, :company, nullable: true
            string :country_code, nullable: true, example: 'US', description: 'ISO-3166 alpha-2 country code.'
            string :state_code, nullable: true, example: 'NY',
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
            Spree.api.admin_stock_location_serializer
          end

          # Stock locations are shared across stores, so writes are store-wide
          # administration: reads need `read_stock`, writes need `write_settings`.
          def scoped_resource_name
            read_actions.include?(action_name) ? :stock : :settings
          end

          def scope
            super.order_default
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
