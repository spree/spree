module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::Core::CalculatedAdjustments
        include Spree::Core::AdjustmentSource

        has_many :adjustments, as: :source

        delegate :eligible?, to: :promotion

        before_validation :ensure_action_has_calculator
        before_destroy :deals_with_adjustments_for_deleted_source

        def perform(payload = {})
          order = payload[:order]
          # Find only the orders' line items which have not already been adjusted by this promotion
          # HACK: Need to use [0] because `pluck` may return an empty array, which AR helpfully
          # coverts to meaning NOT IN (NULL) and the DB isn't happy about that.
          already_adjusted_line_items = [0] + self.adjustments.
            where(adjustable_id: order.line_items.pluck(:id), adjustable_type: 'Spree::LineItem').
            pluck(:adjustable_id)
          result = false
          order.line_items.where("id NOT IN (?)", already_adjusted_line_items).find_each do |line_item|
            current_result = self.create_adjustment(line_item, order)
            result ||= current_result
          end
          return result
        end

        def create_adjustment(adjustable, order)
          amount = self.compute_amount(adjustable)
          return if amount == 0
          return if promotion.product_ids.present? and !promotion.product_ids.include?(adjustable.product.id)
          self.adjustments.create!(
            amount: amount,
            adjustable: adjustable,
            order: order,
            label: "#{Spree.t(:promotion)} (#{promotion.name})",
          )
          true
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(adjustable)
          promotion_amount = self.calculator.compute(adjustable).to_f.abs

          [adjustable.amount, promotion_amount].min * -1
        end

        private
          # Tells us if there if the specified promotion is already associated with the line item
          # regardless of whether or not its currently eligible. Useful because generally
          # you would only want a promotion action to apply to line item no more than once.
          #
          # Receives an adjustment +source+ (here a PromotionAction object) and tells
          # if the order has adjustments from that already
          def promotion_credit_exists?(adjustable)
            self.adjustments.where(:adjustable_id => adjustable.id).exists?
          end

          def ensure_action_has_calculator
            return if self.calculator
            self.calculator = Calculator::PercentOnLineItem.new
          end

      end
    end
  end
end
