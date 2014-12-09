# Base class for all types of promotion action.
# PromotionActions perform the necessary tasks when a promotion is activated by an event and determined to be eligible.
module Spree
  class PromotionAction < Spree::Base
    acts_as_paranoid

    belongs_to :promotion, class_name: 'Spree::Promotion'

    scope :of_type, ->(t) { where(type: t) }

    # This method should be overriden in subclass
    # Updates the state of the order or performs some other action depending on the subclass
    # options will contain the payload from the event that activated the promotion. This will include
    # the key :user which allows user based actions to be performed in addition to actions on the order
    def perform(options = {})
      raise 'perform should be implemented in a sub-class of PromotionAction'
    end

    protected

    def accumulated_total(adjustable)
      return unless adjustable.respond_to?(:promotion_accumulator)
      adjustable.promotion_accumulator.total_with_promotion(promotion_id)
    end

    def create_adjustment(order, adjustable)
      amount = compute_amount(adjustable)
      return if amount == 0
      adjustment = adjustable.adjustments.new(order: order,
                                              source: self,
                                              label: label,
                                              amount: amount)
      adjustment.save
    end

    def label
      "#{Spree.t(:promotion)} (#{promotion.name})"
    end
  end
end
