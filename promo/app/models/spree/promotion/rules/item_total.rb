# A rule to limit a promotion to a specific user.
module Spree
  class Promotion::Rules::ItemTotal < PromotionRule
    preference :amount, :decimal, :default => 100.00
    preference :operator, :string, :default => '>'

    attr_accessible :preferred_amount, :preferred_operator

    OPERATORS = ['gt', 'gte']

    def eligible?(order, options = {})
      item_total = order.line_items.map(&:amount).sum
      item_total.send(preferred_operator == 'gte' ? :>= : :>, BigDecimal.new(preferred_amount.to_s))
    end
  end
end
