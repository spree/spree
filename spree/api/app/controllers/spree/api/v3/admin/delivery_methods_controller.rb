module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodsController < ResourceController
          scoped_resource :delivery_methods

          # A single POST/PATCH can ship eligibility rules and carrier service
          # rows alongside the basics; `DeliveryMethod#rules=` / `#services=`
          # reconcile to the desired set, so the dashboard saves the whole
          # sheet in one round-trip.
          request_params 'DeliveryMethodParams' do |body|
            body.attribute :name, :string, example: 'Express'
            body.attribute :admin_name, :string, nullable: true
            body.attribute :code, :string, nullable: true
            body.attribute :fulfillment_provider, :string,
              example: 'manual',
              description: 'Fulfillment provider shorthand (see the fulfillment providers endpoint), e.g. `manual`.'
            body.attribute :pickup_point_provider, :string, nullable: true
            body.attribute :rate_provider, :string,
              nullable: true,
              description: 'Rate provider shorthand (see the rate providers endpoint), e.g. `easy_post`. Omit or send null for the built-in provider, which prices through the method\'s calculator.'
            body.attribute :storefront_visible, :boolean
            body.attribute :available_to_sellers, :boolean,
              description: "Marketplace only: whether a seller's packages may be quoted by this method. Off by default, and refused on a method that belongs to a seller."
            body.attribute :tracking_url, :string, nullable: true
            body.attribute :estimated_transit_business_days_min, :integer, nullable: true
            body.attribute :estimated_transit_business_days_max, :integer, nullable: true
            body.attribute :tax_category_id, :id,
              nullable: true,
              description: 'Prefixed tax category ID (`taxcat_...`), or null to clear.'
            body.attribute :markup_flat, :decimal,
              nullable: true,
              description: 'Method-level flat handling fee added on top of provider-quoted rates.'
            body.attribute :markup_percent, :decimal,
              nullable: true,
              description: 'Method-level percentage handling fee added on top of provider-quoted rates. Ignored for calculator-priced methods.'
            body.attribute :delivery_profile_id, :id,
              example: 'fp_86Rf07xd4z',
              description: 'Delivery profile this method belongs to (`fp_...`); defaults to the store default profile.'
            body.attribute :delivery_origin_group_id, :id,
              description: "Origin group offering this method (`og_...`); defaults to the zone's group, else the profile's default group."
            body.attribute :delivery_zone_id, :id,
              nullable: true,
              description: "Delivery zone narrowing destinations (`dz_...`), or null for no restriction. Must belong to the method's profile."
            body.attribute :stock_location_ids, :array, of: :id,
              description: 'Pickup locations (`sloc_...`); replaces the full set.'
            body.attribute :calculator, :object,
              description: "How the method prices a shipment: a type from the calculators endpoint and its preferences, matching that type's `schema`." do |calculator|
              calculator.attribute :type, :string, example: 'flat_rate'
              calculator.attribute :preferences, :hash, example: { amount: '12.5' }
            end
            # Permitted by `rule_attributes`, which adds the association-backed
            # config each registered rule kind declares.
            body.attribute :rules, :array,
              permit: false,
              description: 'Eligibility rules. Replaces the full set: omitted rules are removed.' do |rule|
              rule.attribute :id, :id
              rule.attribute :type, :string, description: 'A rule kind from the delivery method rule types endpoint.'
              rule.attribute :active, :boolean
              rule.attribute :preferences, :hash
              rule.attribute :product_ids, :array, of: :id,
                description: 'Products an association-backed rule (`excluded_products_rule`) applies to.'
            end
            body.attribute :services, :array,
              as: 'DeliveryMethodServiceParams',
              description: 'Carrier service rows: which provider services this method offers. Replaces the full set: omitted rows are removed; no rows means every service the provider returns is offered.' do |service|
              service.attribute :id, :id, description: 'Prefixed row ID (`dms_...`) when updating an existing row.'
              service.attribute :carrier, :string,
                required: true,
                example: 'UPS',
                description: "Carrier identifier as the provider's API knows it."
              service.attribute :service, :string,
                required: true,
                example: 'Ground',
                description: "Service identifier as the provider's API knows it."
              service.attribute :label, :string,
                nullable: true,
                description: 'Display label shown to customers instead of the carrier-derived name.'
              service.attribute :markup_flat, :decimal,
                nullable: true,
                description: 'Overrides the method-level flat markup for this service.'
              service.attribute :markup_percent, :decimal,
                nullable: true,
                description: 'Overrides the method-level percentage markup for this service.'
              service.attribute :position, :integer
            end
          end

          # GET /api/v3/admin/delivery_methods/calculators
          # Registered delivery calculator classes with their preference
          # schemas, so admin UIs can render configuration forms.
          def calculators
            authorize! :create, model_class

            data = Spree::DeliveryMethod.calculators.map do |calculator_class|
              {
                type: calculator_class.api_type,
                name: calculator_class.description,
                schema: calculator_class.preference_json_schema
              }
            end

            render json: { data: data }
          end

          # GET /api/v3/admin/delivery_methods/fulfillment_providers
          # Registered FulfillmentProvider strategies with their class
          # predicates, so admin UIs render capability hints from the
          # registry, not JS constants.
          def fulfillment_providers
            authorize! :create, model_class

            data = Spree.fulfillment_providers.map do |provider_class|
              {
                type: provider_class.api_type,
                name: provider_class.provider_name,
                integration_type: integration_api_type(provider_class),
                available: provider_class.available_for_store?(current_store),
                digital: provider_class.digital?,
                pickup: provider_class.pickup?,
                pickup_point: provider_class.pickup_point?,
                requires_address: provider_class.new.requires_address?
              }
            end

            render json: { data: data }
          end

          # GET /api/v3/admin/delivery_methods/rate_providers
          # Registered DeliveryRateProvider strategies. Providers whose
          # integration isn't connected come back with `available: false` so
          # the dashboard can offer connecting it inline — DeliveryMethod
          # still rejects an unavailable provider on save. `service_catalog`
          # feeds the carrier-services picker (empty = free-form).
          def rate_providers
            authorize! :create, model_class

            data = Spree.delivery_rate_providers.map do |provider_class|
              integration = provider_class.integration_class.presence &&
                current_store.integrations.active.find_by(type: provider_class.integration_class)
              catalog = provider_class.service_catalog(integration)

              {
                type: provider_class.api_type,
                name: provider_class.provider_name,
                integration_type: integration_api_type(provider_class),
                available: provider_class.available_for_store?(current_store),
                requires_address: provider_class.requires_address?,
                uses_calculator: provider_class.uses_calculator?,
                service_catalog: catalog.services,
                # Present when the provider could not list services (e.g. a
                # credential tier without access) — the picker shows it
                # instead of an empty list.
                service_catalog_error: catalog.error_message
              }
            end

            render json: { data: data, default: Spree::ApiTyped.api_type_for(Spree::DeliveryMethod::DEFAULT_RATE_PROVIDER) }
          end

          def create
            @resource = model_class.new(assignable_params)
            authorize_resource!(@resource, :create)
            @resource.assign_calculator_attributes(permitted_params[:calculator])

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            saved = save_atomically do
              @resource.assign_attributes(assignable_params)
              @resource.assign_calculator_attributes(permitted_params[:calculator])
            end

            if saved
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          # Wire shorthand of the provider's integration (`easy_post`), so the
          # dashboard can tie a provider to the integration it needs without
          # translating Ruby class names client-side.
          def integration_api_type(provider_class)
            klass = provider_class.integration_class.presence&.safe_constantize
            klass&.api_type
          end

          def model_class
            Spree::DeliveryMethod
          end

          def serializer_class
            Spree.api.admin_delivery_method_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes, rules: rule_attributes)
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
            [:calculator, :tax_category, :delivery_zone, :delivery_profile, :delivery_method_rules, :seller]
          end

          private

          # Resolves prefixed-ID params to records; calculator handled separately.
          def assignable_params
            attributes = permitted_params.except(:tax_category_id, :delivery_profile_id, :delivery_origin_group_id, :delivery_zone_id, :stock_location_ids, :calculator)
            if params.key?(:tax_category_id)
              attributes[:tax_category] = params[:tax_category_id].present? ? Spree::TaxCategory.accessible_by(current_ability, :show).find_by_prefix_id!(params[:tax_category_id]) : nil
            end
            if params.key?(:delivery_profile_id)
              attributes[:delivery_profile] = current_store.delivery_profiles.accessible_by(current_ability, :show).find_by_prefix_id!(params[:delivery_profile_id])
            end
            if params.key?(:delivery_origin_group_id) && params[:delivery_origin_group_id].present?
              attributes[:delivery_origin_group] = current_store.delivery_origin_groups.accessible_by(current_ability, :show).find_by_prefix_id!(params[:delivery_origin_group_id])
            end
            if params.key?(:delivery_zone_id)
              attributes[:delivery_zone] = params[:delivery_zone_id].present? ? current_store.delivery_zones.accessible_by(current_ability, :show).find_by_prefix_id!(params[:delivery_zone_id]) : nil
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
        end
      end
    end
  end
end
