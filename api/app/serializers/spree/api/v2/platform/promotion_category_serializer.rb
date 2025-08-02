module Spree
  module Api
    module V2
      module Platform
        class PromotionCategorySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :promotions, serializer: Spree::Api::Dependencies.platform_promotion_serializer.constantize
        end
      end
    end
  end
end
