module Spree
  module Api
    module V2
      module Platform
        class PromotionActionLineItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :promotion_action
          belongs_to :variant
        end
      end
    end
  end
end
