module Spree
  module Api
    module V3
      module Admin
        class PromotionsController < ResourceController
          scoped_resource :promotions

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

          # A single POST/PATCH /promotions can ship rules and actions
          # alongside the basics; `Promotion#rules=` / `actions=` reconcile
          # to the desired set. The nested allowlist below is the union of
          # every built-in rule/action's expected keys. Plugin-defined
          # subclasses can add to it — see `additional_permitted_attributes`
          # below.
          def permitted_params
            normalize_params(params.permit(*permitted_attributes))
          end

          def permitted_attributes
            [
              :name, :description, :code, :path,
              :starts_at, :expires_at, :usage_limit, :match_policy,
              :kind, :multi_codes, :number_of_codes, :code_prefix,
              :promotion_category_id,
              rules: rule_attributes,
              actions: action_attributes
            ]
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
