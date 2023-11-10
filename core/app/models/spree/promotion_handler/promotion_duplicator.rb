module Spree
  module PromotionHandler
    class PromotionDuplicator < Spree::PromotionDuplicatorCore
      def duplicate
        new_promotion = @promotion.dup
        new_promotion.path = "#{@promotion.path}_#{@random_string}"
        new_promotion.name = "New #{@promotion.name}"
        new_promotion.code = "#{@promotion.code}_#{@random_string}"
        new_promotion.stores = @promotion.stores

        ActiveRecord::Base.transaction do
          new_promotion.save
          copy_rules(new_promotion)
          copy_actions(new_promotion)
        end

        new_promotion
      end
    end
  end
end
