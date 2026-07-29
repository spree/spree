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

          def permitted_params
            params.permit(
              :name, :admin_name, :code, :fulfillment_type, :fulfillment_provider,
              :pickup_point_provider, :storefront_visible, :tracking_url,
              :estimated_transit_business_days_min, :estimated_transit_business_days_max,
              :tax_category_id, :calculator_type,
              delivery_zone_ids: [], stock_location_ids: [], calculator_preferences: {}
            )
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
            attributes
          end

          def assign_calculator(delivery_method)
            calculator_type = permitted_params[:calculator_type]
            preferences = permitted_params[:calculator_preferences]

            if calculator_type.present? && delivery_method.calculator&.type != calculator_type
              unless Spree::DeliveryMethod.calculators.map(&:to_s).include?(calculator_type)
                delivery_method.errors.add(:calculator_type, :invalid)
                return
              end

              delivery_method.calculator = calculator_type.constantize.new
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
