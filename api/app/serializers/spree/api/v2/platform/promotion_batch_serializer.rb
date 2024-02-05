module Spree
  module Api
    module V2
      module Platform
        class PromotionBatchSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :template_promotion, serializer: PromotionSerializer

          has_many :promotions
        end
      end
    end
  end
end
