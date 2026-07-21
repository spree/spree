module Spree
  module Api
    module V3
      module Admin
        # CRUD for `Spree::OrderRoutingRule` STI subclasses, nested under the
        # owning channel. Same shape as PromotionRulesController — the registry
        # is `Spree.order_routing.rules` and the parent is a Channel.
        class OrderRoutingRulesController < ResourceController
          include Spree::Api::V3::Admin::SubclassedResource

          scoped_resource :settings

          subclassed_via -> { Spree.order_routing.rules },
                         unknown_type_error: 'unknown_order_routing_rule_type'

          def types
            authorize! :read, model_class

            render json: { data: model_class.subclasses_with_preference_schema }
          end

          protected

          def model_class
            Spree::OrderRoutingRule
          end

          def serializer_class
            Spree.api.admin_order_routing_rule_serializer
          end

          def permitted_params
            params.permit(:type, :active, :position, preferences: {})
          end

          # `types` is read-only discovery — maps to the read scope + :show ability.
          def read_actions
            super + %w[types]
          end

          def scope
            super.ordered
          end

          def set_parent
            return if action_name == 'types'

            @parent = current_store.channels.accessible_by(current_ability, parent_ability_action)
                                   .find_by_prefix_id!(params[:channel_id])
          end

          def parent_association
            :order_routing_rules
          end

          private

          def build_subclassed_resource(klass, attrs)
            klass.new(attrs.merge(channel: @parent, store: @parent.store))
          end
        end
      end
    end
  end
end
