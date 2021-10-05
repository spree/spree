module Spree
  module Api
    module V2
      module Platform
        class PromotionRuleSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :promotion
        end
      end
    end
  end
end
