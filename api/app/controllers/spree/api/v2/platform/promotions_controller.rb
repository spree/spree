module Spree
  module Api
    module V2
      module Platform
        class PromotionsController < ResourceController
          include ::Spree::Api::V2::PromotionHelper

          private

          def model_class
            Spree::Promotion
          end

          def scope_includes
            [:promotion_category, :promotion_rules, :promotion_actions]
          end
        end
      end
    end
  end
end
