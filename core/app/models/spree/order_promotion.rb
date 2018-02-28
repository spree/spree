module Spree
  class OrderPromotion < Spree::Base
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'

    after_destroy :remove_adjustments_and_line_items

    private

    def remove_adjustments_and_line_items
      return true unless promotion
      remove_promotion_adjustments
      remove_promotion_line_items
      order.update_with_updater!
    end

    def remove_promotion_adjustments
      promotion_actions_ids = promotion.actions.pluck(:id)

      order.all_adjustments.where(source_id: promotion_actions_ids,
                                  source_type: 'Spree::PromotionAction').
        destroy_all
    end

    def remove_promotion_line_items
      create_line_item_actions_ids = promotion.actions.where(type: Spree::Promotion::CREATING_ITEM_ACTIONS).pluck(:id)

      Spree::PromotionActionLineItem.where(promotion_action: create_line_item_actions_ids).find_each do |item|
        line_item = order.find_line_item_by_variant(item.variant)
        next if line_item.blank?
        order.contents.remove(item.variant, item.quantity)
      end
    end
  end
end
