module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodsController < ResourceController
          scoped_resource :settings

          # GET /api/v3/admin/delivery_methods/calculators
          # Registered delivery calculator classes with their preference
          # schemas, so admin UIs can render configuration forms.
          def calculators
            authorize! :create, model_class

            data = Spree::DeliveryMethod.calculators.map do |calculator_class|
              {
                type: calculator_class.to_s,
                name: calculator_class.description,
                preference_schema: calculator_class.respond_to?(:serialized_preference_schema) ? calculator_class.serialized_preference_schema : []
              }
            end

            render json: { data: data }
          end

          # GET /api/v3/admin/delivery_methods/fulfillment_providers
          # Registered FulfillmentProvider strategies plus the registered
          # fulfillment-type vocabulary (Spree.fulfillment_types — the strict
          # set both DeliveryMethod and ProductType validate against), so
          # admin UIs render both lists from the registry, not JS constants.
          def fulfillment_providers
            authorize! :create, model_class

            data = Spree.fulfillment_providers.map do |provider_class|
              {
                type: provider_class.to_s,
                name: provider_class.provider_name,
                fulfillment_types: provider_class.fulfillment_types,
                requires_address: provider_class.new.requires_address?
              }
            end

            render json: { data: data, fulfillment_types: Spree.fulfillment_types }
          end

          def create
            @resource = model_class.new(assignable_params)
            authorize_resource!(@resource, :create)
            assign_calculator(@resource)

            if @resource.errors.empty? && @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            @resource.assign_attributes(assignable_params)
            assign_calculator(@resource)

            if @resource.errors.empty? && @resource.save
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          def model_class
            Spree::DeliveryMethod
          end

          def serializer_class
            Spree.api.admin_delivery_method_serializer
          end

          # A single POST/PATCH can ship eligibility rules alongside the
          # basics; `DeliveryMethod#rules=` reconciles to the desired set, so
          # the dashboard saves the whole sheet in one round-trip.
          def permitted_params
            params.permit(
              :name, :admin_name, :code, :fulfillment_type, :fulfillment_provider,
              :pickup_point_provider, :storefront_visible, :tracking_url,
              :estimated_transit_business_days_min, :estimated_transit_business_days_max,
              :tax_category_id, :calculator_type,
              delivery_zone_ids: [], stock_location_ids: [], calculator_preferences: {},
              rules: rule_attributes
            )
          end

          def rule_attributes
            [:id, :type, :active, { preferences: {} }, *subclassed_rule_attributes]
          end

          # Association-backed rule config declares itself on the rule class
          # (e.g. `[product_ids: []]`), so plugin-defined rules need no change
          # here.
          def subclassed_rule_attributes
            Spree.delivery_method_rules.flat_map do |klass|
              klass.respond_to?(:additional_permitted_attributes) ? klass.additional_permitted_attributes : []
            end.uniq
          end

          def collection_includes
            [:calculator, :tax_category, :delivery_zones]
          end

          private

          # Resolves prefixed-ID params to records; calculator handled separately.
          def assignable_params
            attributes = permitted_params.except(:tax_category_id, :delivery_zone_ids, :stock_location_ids, :calculator_type, :calculator_preferences)
            if params.key?(:tax_category_id)
              attributes[:tax_category] = params[:tax_category_id].present? ? Spree::TaxCategory.accessible_by(current_ability, :show).find_by_prefix_id!(params[:tax_category_id]) : nil
            end
            if params.key?(:delivery_zone_ids)
              attributes[:delivery_zones] = Array(params[:delivery_zone_ids]).map { |id| current_store.delivery_zones.accessible_by(current_ability, :show).find_by_prefix_id!(id) }
            end
            if params.key?(:stock_location_ids)
              attributes[:pickup_locations] = Array(params[:stock_location_ids]).map { |id| current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id) }
            end
            attributes[:rules] = resolved_rule_rows if params.key?(:rules)
            attributes
          end

          # `DeliveryMethod#rules=` decodes prefixed ids but applies no store
          # or ability scoping, so resolve association-backed config here — a
          # product the caller cannot reach 404s rather than silently linking.
          def resolved_rule_rows
            Array(permitted_params[:rules]).map do |row|
              row = row.to_h
              row['product_ids'].blank? ? row : row.merge('product_ids' => accessible_product_ids(row['product_ids']))
            end
          end

          # Keeps only the products this caller can reach in this store, and
          # plucks ids rather than hydrating rows to read them back. Ids that
          # resolve to nothing — another store's, or a product deleted while
          # the sheet was open — are dropped: they cannot become an exclusion,
          # and failing the whole save over one would leave the merchant stuck
          # with no way to clear it. Mirrors how price lists filter membership.
          def accessible_product_ids(ids)
            current_store.products.
              accessible_by(current_ability, :show).
              where(id: decode_prefixed_ids(ids)).
              pluck(:id)
          end

          def assign_calculator(delivery_method)
            calculator_type = permitted_params[:calculator_type]
            preferences = permitted_params[:calculator_preferences]

            if calculator_type.present? && delivery_method.calculator&.type != calculator_type
              selected_calculator_class = Spree::DeliveryMethod.calculators.find { |klass| klass.to_s == calculator_type }
              unless selected_calculator_class
                delivery_method.errors.add(:calculator_type, :invalid)
                return
              end

              delivery_method.calculator = selected_calculator_class.new
            end

            return if preferences.blank? || delivery_method.calculator.nil?

            preferences.each do |key, value|
              next unless delivery_method.calculator.has_preference?(key)

              delivery_method.calculator.set_preference(key, value)
            end
          end
        end
      end
    end
  end
end
