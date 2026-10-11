module Spree
  module Api
    module V3
      module Admin
        class PromotionsController < ResourceController
          scoped_resource :promotions

          request_params :promotion do
            string :name, required: :create
            string :description, nullable: true
            string :code, nullable: true,
                          description: 'Required for single-code coupon promotions. Ignored when `multi_codes` is true.'
            string :path, nullable: true
            datetime :starts_at, :expires_at, nullable: true
            integer :usage_limit, nullable: true
            string :match_policy, enum: Spree::Promotion::MATCH_POLICIES
            string :kind, enum: Spree::Promotion.kinds.keys,
                          description: '`coupon_code` needs a code (or `multi_codes`); `automatic` applies without one.'
            boolean :multi_codes, description: 'Generates `number_of_codes` codes starting with `code_prefix`.'
            integer :number_of_codes, nullable: true
            string :code_prefix, nullable: true
            id :promotion_category_id, nullable: true
            # Rules and actions are permitted below, with the keys each
            # registered kind adds.
            object :rules, array: true, permit: false, as: 'PromotionRuleDraftParams',
                           description: 'The rules the promotion should have: entries with `id` update, entries without are created, and rules left out are removed.' do
              id :id
              string :type, required: true, example: 'currency',
                            description: 'The rule kind, from `GET /promotion_rules/types`.'
              include_fields Spree::Api::V3::RequestShapes::PROMOTION_RULE_FIELDS
            end
            object :actions, array: true, permit: false, as: 'PromotionActionDraftParams',
                             description: 'The actions the promotion should have, matched the same way as `rules`.' do
              id :id
              string :type, required: true, example: 'free_shipping',
                            description: 'The action kind, from `GET /promotion_actions/types`.'
              include_fields Spree::Api::V3::RequestShapes::PROMOTION_ACTION_FIELDS
            end
          end

          protected

          def model_class
            Spree::Promotion
          end

          def serializer_class
            Spree.api.admin_promotion_serializer
          end

          def collection_includes
            promotion_includes
          end

          def scope_includes
            promotion_includes
          end

          # `Promotion#rules=` / `actions=` reconcile to the desired set. The
          # nested allowlists are the union of every registered rule/action
          # kind's keys, so plugin-defined kinds add to them through
          # `additional_permitted_attributes`.
          def resource_permitted_attributes
            [*super, { rules: rule_attributes, actions: action_attributes }]
          end

          def rule_attributes
            [:id, :type, { preferences: {} }, *subclassed_collection_attributes(Spree.promotions.rules)]
          end

          def action_attributes
            [
              :id, :type,
              { preferences: {} },
              { calculator: [:type, { preferences: {} }] },
              *subclassed_collection_attributes(Spree.promotions.actions)
            ]
          end

          # Pulls in plugin-defined permitted attributes from every
          # registered rule/action subclass. Subclasses declare these via
          # `additional_permitted_attributes` (e.g. `[product_ids: []]`).
          def subclassed_collection_attributes(registry)
            registry.flat_map do |klass|
              klass.respond_to?(:additional_permitted_attributes) ? klass.additional_permitted_attributes : []
            end.uniq
          end

          private

          def promotion_includes
            [:promotion_actions, :promotion_rules]
          end
        end
      end
    end
  end
end
