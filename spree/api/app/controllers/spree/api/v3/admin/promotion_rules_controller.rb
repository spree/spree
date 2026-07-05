module Spree
  module Api
    module V3
      module Admin
        # CRUD for `Spree::PromotionRule` STI subclasses. Same shape as
        # PromotionActionsController — only the registry differs
        # (`Spree.promotions.rules` instead of `Spree.promotions.actions`).
        class PromotionRulesController < ResourceController
          include Spree::Api::V3::Admin::SubclassedResource

          scoped_resource :promotions

          subclassed_via -> { Spree.promotions.rules },
                         unknown_type_error: 'unknown_promotion_rule_type'

          def types
            authorize! :read, model_class

            render json: { data: model_class.subclasses_with_preference_schema }
          end

          protected

          def model_class
            Spree::PromotionRule
          end

          def serializer_class
            Spree.api.admin_promotion_rule_serializer
          end

          def permitted_params
            params.permit(:type, preferences: {})
          end

          def set_parent
            return if action_name == 'types'

            @parent = current_store.promotions.accessible_by(current_ability, :update)
                                   .find_by_prefix_id!(params[:promotion_id])
          end

          def parent_association
            :promotion_rules
          end

          private

          def build_subclassed_resource(klass, attrs)
            klass.new(attrs.merge(promotion: @parent))
          end
        end
      end
    end
  end
end
