module Spree
  module Api
    module V3
      module Admin
        # What this marketplace asks of a seller before it will let them
        # trade (docs/plans/6.0-seller-onboarding-requirements.md).
        #
        # Under `write_sellers` rather than `settings`: who decides admission
        # is who admits, and a key that can approve sellers is the same key
        # that should be able to change what approval requires.
        class SellerRequirementsController < ResourceController
          include Spree::Api::V3::Admin::SubclassedResource

          scoped_resource :sellers

          subclassed_via -> { Spree.seller_requirements },
                         unknown_type_error: 'unknown_seller_requirement_type'

          # GET /api/v3/admin/seller_requirements/types
          #
          # The kinds an operator can add, with the shape of each one's
          # configuration form. A marketplace's own kinds appear here the
          # moment they are registered, which is what keeps the picker from
          # being a hardcoded list in the dashboard.
          def types
            # `:read`, matching its place in `read_actions`: this lists the
            # kinds a marketplace has registered and nothing about any store,
            # so a staffer who can see the checklist can see what it is made
            # of. Asking for `:create` here 403s exactly those people.
            authorize! :read, model_class

            data = Spree.seller_requirements.map do |klass|
              {
                type: klass.api_type,
                name: klass.human_name,
                description: klass.human_description,
                allow_multiple: klass.allow_multiple?,
                accepts_submissions: klass.accepts_submissions?,
                reviewed_by_operator: klass.reviewed_by_operator?,
                # Whether the store already has one, and whether it may add
                # another — the uniqueness rule is the model's, so the picker
                # reads the answer rather than reimplementing it.
                configured: configured_types.include?(klass.to_s),
                addable: klass.allow_multiple? || configured_types.exclude?(klass.to_s),
                # What a seller may upload, for kinds that collect a file.
                # Told to the operator, never asked of them — the answer is
                # the same for every marketplace.
                accepted_content_types: klass.accepted_content_types,
                # Config a kind takes beyond its preferences — a reference
                # list gets its own picker, not a text box.
                association_fields: association_fields_for(klass),
                preference_schema: klass.serialized_preference_schema
              }
            end

            render json: { data: data }
          end

          protected

          def model_class
            Spree::SellerRequirement
          end

          def serializer_class
            Spree.api.admin_seller_requirement_serializer
          end

          def scope
            super.ordered
          end

          # `type` is stripped before assignment by the subclassed-resource
          # flow, so a saved row's kind can never change — which matters
          # because its submissions answered the old one.
          def permitted_params
            params.permit(:type, :name, :description, :position, :active, :required,
                          preferences: {}, metadata: {})
          end

          # `types` is read-only discovery — maps to the read scope.
          def read_actions
            super + %w[types]
          end

          private

          # `additional_permitted_attributes` entries are either bare symbols
          # or `{ custom_field_definition_ids: [] }` hashes; both reduce to
          # field names an editor can render a picker for.
          def association_fields_for(klass)
            return [] unless klass.respond_to?(:additional_permitted_attributes)

            klass.additional_permitted_attributes.flat_map do |attribute|
              attribute.is_a?(Hash) ? attribute.keys : attribute
            end.map(&:to_s)
          end

          def build_subclassed_resource(klass, attrs)
            current_store.seller_requirements.build(attrs.merge(type: klass.sti_name))
          end

          # `pluck` queries whether or not the association is already loaded,
          # so a warm `current_store` cannot leave this answering with a kind
          # the store no longer has. `reorder(nil)` because the association
          # orders by position, and PostgreSQL refuses SELECT DISTINCT with an
          # ORDER BY on a column it does not select.
          def configured_types
            @configured_types ||= current_store.seller_requirements.reorder(nil).distinct.pluck(:type)
          end
        end
      end
    end
  end
end
