module Spree
  module Api
    module V3
      module Admin
        # Custom field values for any parent that includes the custom-fields
        # concern. Mounted via the `:custom_fieldable` route concern; the parent
        # class is inferred from whichever `<segment>_id` route param matches a
        # registered owner.
        class CustomFieldsController < ResourceController
          # POST /api/v3/admin/<parent>/<parent_id>/custom_fields
          def create
            @resource = @parent.metafields.new(permitted_params)
            authorize_resource!(@resource, :create)

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          # PATCH /api/v3/admin/<parent>/<parent_id>/custom_fields/:id
          # Only `value` is mutable. Switching the linked definition is a
          # delete-and-create — the model rejects it (definition + resource
          # uniqueness) and the type wouldn't match.
          def update
            authorize_resource!(@resource)

            if @resource.update(update_permitted_params)
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          def model_class
            Spree::CustomField
          end

          def serializer_class
            Spree.api.admin_custom_field_serializer
          end

          def parent_association
            :metafields
          end

          def set_parent
            # Routes always mount this controller under a recognized parent, so
            # `parent_lookup` matches in normal flows. The explicit raise is a
            # defensive guard against a future route nesting that doesn't.
            raise ActiveRecord::RecordNotFound, 'Parent resource not found' unless parent_lookup

            @parent = parent_lookup.klass.find_by_prefix_id!(parent_lookup.value)
          end

          # Per-parent scope check: a key holding `write_products` may write a
          # product's custom fields, `write_orders` may write an order's, etc.
          # Resolves the parent at request time rather than via the static
          # `scoped_resource` declaration.
          def scoped_resource_name
            parent_lookup&.segment&.pluralize&.to_sym
          end

          # `custom_field_definition_id` is an alias_attribute on Spree::CustomField;
          # AR resolves the prefixed-ID and the alias to the canonical FK on assign.
          def permitted_params
            params.permit(:custom_field_definition_id, :value)
          end

          def update_permitted_params
            params.permit(:value)
          end

          private

          ParentLookup = Struct.new(:klass, :value, :segment)

          # Stores class names (not class objects) so the map survives dev-mode
          # code reloads — `enabled_resources` is captured at boot and its
          # class references go stale. Aliases `'customer'` because the route
          # uses `customer_id` while user_class.model_name.element is `'user'`.
          def parent_route_map
            @parent_route_map ||= Spree.metafields.enabled_resources.each_with_object({}) do |klass, m|
              m[klass.model_name.element.to_s] = klass.name
            end.merge('customer' => Spree.user_class.name)
          end

          # Returns the first segment whose `<segment>_id` is present in params,
          # paired with its class and the raw id value, or nil. Memoized — read
          # by both `set_parent` and `scoped_resource_name`.
          def parent_lookup
            return @parent_lookup if defined?(@parent_lookup)

            match = parent_route_map.find { |segment, _| params[:"#{segment}_id"].present? }
            @parent_lookup =
              if match
                segment, klass_name = match
                ParentLookup.new(klass_name.constantize, params[:"#{segment}_id"], segment)
              end
          end
        end
      end
    end
  end
end
