module Spree
  module Api
    module V2
      module Platform
        class PromotionRuleSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :user_id, :product_group_id

          belongs_to :promotion
        end
      end
    end
  end
end
