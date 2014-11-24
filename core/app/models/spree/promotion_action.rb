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
    attr_accessor :order, :amount
    delegate :item_total, :ship_total, :adjustment_total, to: :order
    delegate :compute, to: :calculator

    def amount_must_not_exceed_available_amount
      @amount = [available_amount, amount].min
    end

    def available_amount
      item_total + ship_total - adjustment_total
    end

    def update_available_amount
      order.adjustment_total += amount
    end

    def label
      "#{Spree.t(:promotion)} (#{promotion.name})"
    end

  end
end
