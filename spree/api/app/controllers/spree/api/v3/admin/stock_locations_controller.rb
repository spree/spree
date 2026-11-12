module Spree
  module Api
    module V3
      module Admin
        class StockLocationsController < ResourceController
          scoped_resource :stock

          request_params :stock_location do |body|
            body.external_references
            body.attribute :name, :string, required: true, on: :create, example: 'Brooklyn warehouse'
            body.attribute :admin_name, :string, nullable: true, description: 'Internal name shown only in the admin.'
            body.attribute :active, :boolean
            body.attribute :default, :boolean, description: 'Setting to true demotes the previous default.'
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
              example: 'NY',
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
