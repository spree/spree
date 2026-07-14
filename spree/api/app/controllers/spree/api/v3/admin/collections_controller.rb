module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for collections — the flat, merchandising half of today's
        # dual-purpose Taxon. Both manual and automatic (rule-based) collections
        # live here. Reordering is a plain +position+ update (acts_as_list
        # reorders siblings on save), matching the SPA ResourceTable reorder
        # convention, so there is no dedicated reposition action.
        class CollectionsController < ResourceController
          scoped_resource :collections

          protected

          def model_class
            Spree::Collection
          end

          def serializer_class
            Spree.api.admin_collection_serializer
          end

          # The serializer always renders the rule set — eager load it.
          def scope_includes
            [:rules]
          end

          # Flat params. +rules+ is applied by the model's sync setter
          # (Spree::Collection#rules=): the full desired rule set, prefixed
          # +crule_+ ids update, missing ids build, omitted rules are removed —
          # so normalize_params is deliberately NOT called (that would rewrite
          # +rules+ to +rules_attributes+ and route past the setter).
          def permitted_params
            params.permit(
              :name, :description, :permalink, :position,
              :meta_title, :meta_description, :meta_keywords,
              :image, :square_image,
              :automatic, :rules_match_policy, :sort_order,
              rules: [:id, :type, :value, :match_policy],
              # Inline custom field values keyed by definition id (see
              # CategoriesController#permitted_params for the value shapes).
              custom_fields: [:id, :custom_field_definition_id, :value, { value: [] }, { value: {} }]
            )
          end
        end
      end
    end
  end
end
