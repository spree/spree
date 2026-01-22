module Spree
  module Api
    module V3
      module Store
        class OrderPromotionSerializer < BaseSerializer
          attributes :id, :name, :description, :code, :amount, :display_amount, :promotion_id
        end
      end
    end
  end
end
