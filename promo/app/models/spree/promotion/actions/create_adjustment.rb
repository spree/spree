module Spree
  class Promotion::Actions::CreateAdjustment < PromotionAction
    calculated_adjustments

    delegate :eligible?, :to => :promotion

    before_validation :ensure_action_has_calculator

    def perform(options = {})
      return unless order = options[:order]
      # Nothing to do if the promotion is already associated with the order
      return if order.promotion_credit_exists?(promotion)
      if amount = calculator.compute(order)
        amount = BigDecimal.new(amount.to_s)
        amount = order.item_total if amount > order.item_total
        order.adjustments.promotion.reload.clear
        order.update!
        create_adjustment("#{I18n.t(:promotion)} (#{promotion.name})", order, order)
      end
    end

    # Ensure a negative amount which does not exceed the sum of the order's item_total and ship_total
    def compute_amount(calculable)
      [(calculable.item_total + calculable.ship_total), super.to_f.abs].min * -1
    end

    private
    def ensure_action_has_calculator
      return if self.calculator
      self.calculator = Calculator::FlatPercentItemTotal.new
    end
  end
end
