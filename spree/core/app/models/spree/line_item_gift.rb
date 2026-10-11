module Spree
  # The units of a line a promotion action gave away, so the action pays for
  # those and never for the units the shopper chose themselves.
  class LineItemGift < Spree.base_class
    belongs_to :line_item, class_name: 'Spree::LineItem', inverse_of: :gifts
    belongs_to :promotion_action, -> { with_deleted }, class_name: 'Spree::PromotionAction'

    validates :quantity, numericality: { only_integer: true, greater_than: 0 }
    validates :promotion_action_id, uniqueness: { scope: spree_base_uniqueness_scope + [:line_item_id] }
  end
end
