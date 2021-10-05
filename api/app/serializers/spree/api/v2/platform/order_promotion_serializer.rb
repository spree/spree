module Spree
  module Api
    module V2
      module Platform
        class OrderPromotionSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :promotion
        end
      end
    end
  end
end
