module Spree
  module Api
    module V2
      module Platform
        class PromotionSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :promotion_category

          has_many :promotion_rules
          has_many :promotion_actions
          has_many :stores
        end
      end
    end
  end
end
