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

          request_params :collection do |body|
            body.attribute :name, :string, required: true, on: :create, example: 'On Sale'
            body.attribute :description, :string,
              description: 'Rich text HTML. Reads come back as this (plain text) plus `description_html`.'
            body.attribute :permalink, :string
            body.attribute :position, :integer,
              description: "1-based position among the store's collections; the server shifts its siblings. The nested products reposition endpoints, unlike this, take 0-based indexes."
            body.attribute :meta_title, :string
            body.attribute :meta_description, :string
            body.attribute :meta_keywords, :string
            body.attribute :image_signed_id, :string,
              nullable: true,
              description: 'A `signed_id` from `files.upload()` for the landscape image, or null to remove it.'
            body.attribute :square_image_signed_id, :string,
              nullable: true,
              description: 'A `signed_id` from `files.upload()` for the square image, or null to remove it.'
            body.attribute :automatic, :boolean,
              description: 'When true, membership is materialized from `rules` instead of curated by hand.'
            body.attribute :rules_match_policy, :string,
              choices: Spree::Collection::RULES_MATCH_POLICIES,
              description: 'Whether a product must match all rules or any of them. Defaults to `all`.'
            body.attribute :sort_order, :string,
              choices: Spree::Collection::SORT_ORDERS,
              description: "Default product sort for the storefront listing; a shopper's own sort wins. Defaults to `manual`."
            # Applied by the model's sync setter (Spree::Collection#rules=).
            body.attribute :rules, :array,
              as: 'CollectionRuleParams',
              description: 'The complete desired rule set. Entries with an `id` update, entries without one are created, and existing rules left out are removed.' do |rule|
              rule.attribute :id, :id, example: 'crule_abc123', description: 'Omit to create a new rule.'
              rule.attribute :type, :string,
                example: 'tag',
                description: 'Wire shorthand for the rule kind, from the collection rule types endpoint.'
              rule.attribute :value, :string, example: 'summer'
              rule.attribute :match_policy, :string,
                choices: Spree::CollectionRule::MATCH_POLICIES,
                example: 'contains'
            end
            body.attribute :custom_fields, :array, of: Spree::Api::V3::CustomFieldValueRequestSchema,
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
