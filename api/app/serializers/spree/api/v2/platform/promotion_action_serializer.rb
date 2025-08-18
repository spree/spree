module Spree
  module Api
    module V2
      module Platform
        class PromotionActionSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :promotion, serializer: Spree::Api::Dependencies.platform_promotion_serializer.constantize

          # Some promotion actions have a :calculator, while others do not.
          has_one :calculator, serializer: Spree::Api::Dependencies.platform_calculator_serializer.constantize, if: proc { |record| record.respond_to?(:calculator) }

          # Only the CreateLineItems promotion action uses :promotion_action_line_items.
          has_many :promotion_action_line_items, serializer: Spree::Api::Dependencies.platform_promotion_action_line_item_serializer.constantize, if: proc { |record| record.respond_to?(:promotion_action_line_items) }
        end
      end
    end
  end
end
