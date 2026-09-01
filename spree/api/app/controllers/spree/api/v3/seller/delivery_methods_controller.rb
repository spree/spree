module Spree
  module Api
    module V3
      module Seller
        # How this seller ships: the methods they create, price and retire
        # against the marketplace's profiles and zones
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
        #
        # The listing also carries the marketplace methods the operator shares
        # with sellers, so a seller can see what already ships their goods
        # before adding anything. Those rows are read-only — `find_resource`
        # roots writes in the seller's own methods, so a shared method's id is
        # a 404 on every action but `show`.
        #
        # Carriers stay the marketplace's: a seller's method prices through
        # the internal rate provider and is fulfilled by hand, which is what
        # `Spree::DeliveryMethod` validates and why neither provider is
        # writable here.
        class DeliveryMethodsController < Seller::ResourceController
          scoped_resource :delivery_methods

          # GET /api/v3/seller/delivery_methods/calculators
          # The ways a seller can price a method, with the preference schema
          # each one's form is rendered from.
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

          # GET /api/v3/seller/delivery_methods/rule_types
          # The conditions a seller may put on a method. A subset of the
          # operator's: the rest either segment the marketplace's own traffic
          # or point at catalog rows this branch does not serve.
          def rule_types
            authorize! :create, model_class

            data = seller_rule_classes.map do |klass|
              {
                type: klass.api_type,
                name: klass.human_name,
                description: klass.human_description,
                preference_schema: klass.serialized_preference_schema
              }
            end

            render json: { data: data }
          end

          # Built off `resource_scope` rather than the inherited
          # `build_resource`: the row is born the seller's own that way, and
          # the payload carries calculator fields that are not columns.
          def create
            @resource = resource_scope.new
            @resource.store = current_store
            @resource.assign_attributes(assignable_params)
            authorize_resource!(@resource, :create)
            rederive_origin_group(@resource)
            assign_calculator(@resource)

            if @resource.errors.empty? && @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            @resource.assign_attributes(assignable_params)
            rederive_origin_group(@resource)
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
            Spree.api.seller_delivery_method_serializer
          end

          # Reading shows the seller's own methods plus the marketplace ones
          # shared with them — the same set the estimator will quote their
          # packages by, so the page answers "how do my goods ship" rather
          # than only "what have I made".
          def scope
            current_store.delivery_methods.
              available_to_seller(current_seller).
              includes(*collection_includes).
              preload_associations_lazily
          end

          # Writes root in the seller's own methods, so a shared marketplace
          # method cannot be edited or deleted through this branch.
          def resource_scope
            current_seller.delivery_methods
          end

          def find_resource
            action_name == 'show' ? super : resource_scope.find_by_prefix_id!(params[:id])
          end

          # No provider fields: both are fixed for a seller's method, and
          # permitting them would let a write fail validation for a choice the
          # seller was never offered. No markup either — that prices a
          # carrier's quote, and a seller has no carrier.
          def permitted_params
            params.permit(
              *model_additional_permitted_attributes,
              :name, :admin_name, :code, :storefront_visible, :tracking_url,
              :estimated_transit_business_days_min, :estimated_transit_business_days_max,
              :calculator_type,
              :delivery_profile_id, :delivery_zone_id,
              calculator_preferences: {},
              rules: [:id, :type, :active, { preferences: {} }]
            )
          end

          def collection_includes
            [:calculator, :delivery_zone, :delivery_profile, :delivery_method_rules]
          end

          private

          # Rule kinds this branch does not offer. Channel rules segment the
          # marketplace's own traffic, and the excluded-products rule points at
          # a catalog picker the seller panel does not have — a seller who will
          # not ship something does not list it.
          #
          # Matched by name rather than by class identity: in development the
          # registry holds classes from an earlier reload, so comparing
          # constants silently matches nothing and every kind stays on offer.
          WITHHELD_RULE_TYPES = %w[
            Spree::DeliveryMethodRules::ChannelRule
            Spree::DeliveryMethodRules::ExcludedProductsRule
          ].freeze

          # The rule kinds a seller may put on their own method.
          def seller_rule_classes
            Spree.delivery_method_rules.reject { |klass| WITHHELD_RULE_TYPES.include?(klass.to_s) }
          end

          # Resolves the marketplace vocabulary a seller picks from, through
          # the store: a profile or zone that is not this store's is a 404
          # rather than a validation error, matching how the product form
          # resolves its own pickers.
          def assignable_params
            attributes = permitted_params.except(
              :delivery_profile_id, :delivery_zone_id, :calculator_type, :calculator_preferences, :rules
            )

            if params.key?(:delivery_profile_id)
              attributes[:delivery_profile] = current_store.delivery_profiles.find_by_prefix_id!(params[:delivery_profile_id])
            end

            if params.key?(:delivery_zone_id)
              attributes[:delivery_zone] =
                params[:delivery_zone_id].present? ? current_store.delivery_zones.find_by_prefix_id!(params[:delivery_zone_id]) : nil
            end

            attributes[:rules] = permitted_rule_rows if params.key?(:rules)
            attributes
          end

          # The origin group is derived, never chosen: a seller picks the kind
          # of goods and where it ships, and which warehouses offer the method
          # follows from those. The model derives it only on create, so a
          # profile or zone change here has to re-derive it — otherwise the
          # row keeps a group the new zone contradicts, and the composition
          # validation refuses the save.
          def rederive_origin_group(delivery_method)
            return unless delivery_method.delivery_profile_id_changed? || delivery_method.delivery_zone_id_changed?

            delivery_method.delivery_origin_group =
              delivery_method.delivery_zone&.delivery_origin_group ||
              delivery_method.delivery_profile&.default_origin_group
          end

          # A rule kind this branch does not offer is refused rather than
          # dropped: silently ignoring it would report a save the seller can
          # see did not take.
          def permitted_rule_rows
            allowed = seller_rule_classes.map(&:api_type)

            Array(permitted_params[:rules]).map do |row|
              row = row.to_h
              raise ActiveRecord::RecordNotFound unless allowed.include?(row['type'].to_s)

              row
            end
          end

          def assign_calculator(delivery_method)
            calculator_type = permitted_params[:calculator_type]
            preferences = permitted_params[:calculator_preferences]

            if calculator_type.present? && delivery_method.calculator&.type != calculator_type
              unless Spree::DeliveryMethod.calculators.any? { |klass| klass.to_s == calculator_type }
                delivery_method.errors.add(:calculator_type, :invalid)
                return
              end

              # Constantized from the checked name rather than instantiating
              # the registry's own object: in development the registry holds a
              # class from an earlier reload, and assigning an instance of it
              # fails the association's type check.
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
