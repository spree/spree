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

          PUBLICATIONS_DESCRIPTION = 'The complete set of channels the collection is published on. Channels left out are unpublished. ' \
                                     'Omit on create to publish on every active channel.'.freeze

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
                           deprecated: 'Ignored: a collection is automatic while it has `rules`. Send `rules: []` to remove them. Removed in 6.2.',
                           description: 'Ignored. Membership combines `rules`, hand-picked products and exclusions.'
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
              rule.attribute :value, :string,
                             example: 'summer',
                             description: 'What the rule compares against: a prefixed id for the category, product type and seller types.'
              rule.attribute :match_policy, :string,
                             choices: Spree::CollectionRule::MATCH_POLICIES,
                             example: 'contains',
                             description: 'The relation. Each rule type accepts the `match_policies` the rule types endpoint lists for it.'
              rule.attribute :currency, :currency,
                             nullable: true,
                             description: 'For `price` and `sale` rules: the currency they evaluate in. Null means the default currency of the store.'
              rule.attribute :preferences, :hash,
                             description: 'Values for the settings schema of the rule type, from the rule types endpoint.'
            end
            # Applied by the model's sync setter (Spree::Collection#publications=).
            body.attribute :publications, :array,
                           as: 'CollectionPublicationParams',
                           description: PUBLICATIONS_DESCRIPTION do |publication|
              publication.attribute :channel_id, :id, example: 'ch_abc123'
              publication.attribute :published_at, :datetime,
                                    nullable: true, description: 'When the collection goes live on the channel. Null means immediately.'
              publication.attribute :unpublished_at, :datetime,
                                    nullable: true, description: 'When the collection comes down from the channel. Null means never.'
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
            [:rules, :publications]
          end

          def create_workflow
            Spree.collection_create_workflow
          end

          def scope
            super.ordered
          end

          # normalize_params is deliberately NOT called: it would rewrite
          # +rules+ to +rules_attributes+ and route past the sync setter.
          # `automatic` is accepted for compatibility and dropped: rules decide it.
          def permitted_params
            params.permit(*permitted_attributes).except(:automatic)
          end
        end
      end
    end
  end
end
