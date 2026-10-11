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

          request_params :collection do
            string :name, required: :create, example: 'On Sale'
            string :description, description: 'Rich text HTML. Reads come back as this (plain text) plus `description_html`.'
            string :permalink
            integer :position,
                    description: "1-based position among the store's collections; the server shifts its siblings. The nested products reposition endpoints, unlike this, take 0-based indexes."
            string :meta_title, :meta_description, :meta_keywords
            string :image_signed_id, nullable: true,
                                     description: 'A `signed_id` from `files.upload()` for the landscape image, or null to remove it.'
            string :square_image_signed_id, nullable: true,
                                            description: 'A `signed_id` from `files.upload()` for the square image, or null to remove it.'
            boolean :automatic, description: 'When true, membership is materialized from `rules` instead of curated by hand.'
            string :rules_match_policy, enum: Spree::Collection::RULES_MATCH_POLICIES,
                                        description: 'Whether a product must match all rules or any of them. Defaults to `all`.'
            string :sort_order, enum: Spree::Collection::SORT_ORDERS,
                                description: "Default product sort for the storefront listing; a shopper's own sort wins. Defaults to `manual`."
            # Applied by the model's sync setter (Spree::Collection#rules=).
            object :rules, array: true, as: 'CollectionRuleParams',
                           description: 'The complete desired rule set. Entries with an `id` update, entries without one are created, and existing rules left out are removed.' do
              id :id, example: 'crule_abc123', description: 'Omit to create a new rule.'
              string :type, example: 'tag', description: 'Wire shorthand for the rule kind, from the collection rule types endpoint.'
              string :value, example: 'summer'
              string :match_policy, enum: Spree::CollectionRule::MATCH_POLICIES, example: 'contains'
            end
            object :custom_fields, array: true, shape: Spree::Api::V3::RequestShapes::CUSTOM_FIELD_VALUE,
                                   description: 'Custom field values, each validated against its definition.'
          end

          protected

          def model_class
            Spree::Collection
          end

          def serializer_class
            Spree.api.admin_collection_serializer
          end

          # The serializer always renders the rule set — eager load it.
          # Eager-loaded unconditionally (as PromotionsController does for its
          # own rules): the write path reads the association through the `rules=`
          # sync setter regardless of what the response expands.
          def scope_includes
            [:rules]
          end

          def scope
            super.ordered
          end

          # normalize_params is deliberately NOT called: it would rewrite
          # +rules+ to +rules_attributes+ and route past the sync setter.
          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
