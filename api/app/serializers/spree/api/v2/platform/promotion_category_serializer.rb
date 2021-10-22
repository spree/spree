module Spree
  module Api
    module V2
      module Platform
        class PromotionCategorySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :promotions
        end
      end
    end
  end
end
