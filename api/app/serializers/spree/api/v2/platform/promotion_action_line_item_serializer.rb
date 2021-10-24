module Spree
  module Api
    module V2
      module Platform
        class PromotionActionLineItemSerializer < BaseSerializer
          include ResourceSerializerConcern
          attribute :variant_id

          belongs_to :promotion_action
        end
      end
    end
  end
end
