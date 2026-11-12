module Spree
  module Api
    module V3
      module Admin
        class PromotionsController < ResourceController
          scoped_resource :promotions

          request_params :promotion do |body|
            body.attribute :name, :string, required: true, on: :create
            body.attribute :description, :string, nullable: true
            body.attribute :code, :string,
              nullable: true,
              description: 'Required for single-code coupon promotions. Ignored when `multi_codes` is true.'
            body.attribute :path, :string, nullable: true
            body.attribute :starts_at, :datetime, nullable: true
            body.attribute :expires_at, :datetime, nullable: true
            body.attribute :usage_limit, :integer, nullable: true
            body.attribute :match_policy, :string, choices: Spree::Promotion::MATCH_POLICIES
            body.attribute :kind, :string,
              choices: Spree::Promotion.kinds.keys,
              description: '`coupon_code` needs a code (or `multi_codes`); `automatic` applies without one.'
            body.attribute :multi_codes, :boolean,
              description: 'Generates `number_of_codes` codes starting with `code_prefix`.'
            body.attribute :number_of_codes, :integer, nullable: true
            body.attribute :code_prefix, :string, nullable: true
            body.attribute :promotion_category_id, :id, nullable: true
            # Rules and actions are permitted below, with the keys each
            # registered kind adds.
            body.attribute :rules, :array,
              permit: false,
              as: 'PromotionRuleDraftParams',
              description: 'The rules the promotion should have: entries with `id` update, entries without are created, and rules left out are removed.' do |rule|
              rule.attribute :id, :id
              rule.attribute :type, :string,
                required: true,
                example: 'currency',
                description: 'The rule kind, from `GET /promotion_rules/types`.'
              rule.include_attributes Spree::Api::V3::Admin::PromotionRuleRequestSchema
            end
            body.attribute :actions, :array,
              permit: false,
              as: 'PromotionActionDraftParams',
              description: 'The actions the promotion should have, matched the same way as `rules`.' do |action|
              action.attribute :id, :id
              action.attribute :type, :string,
                required: true,
                example: 'free_shipping',
                description: 'The action kind, from `GET /promotion_actions/types`.'
              action.include_attributes Spree::Api::V3::Admin::PromotionActionRequestSchema
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
