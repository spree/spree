module Spree
  module AdjustmentSource
    extend ActiveSupport::Concern

    included do
      has_many :adjustments, as: :source
      before_destroy :deals_with_adjustments_for_deleted_source
    end

    protected

    def create_adjustment(order, adjustable, promotion_code, included = nil)
      amount = compute_amount(adjustable)
      return if amount == 0
      adjustments.new(order: order,
                      adjustable: adjustable,
                      promotion_code: promotion_code,
                      label: label,
                      amount: amount,
                      included: included).save
    end

    def create_unique_adjustment(order, adjustable, promotion_code)
      return if already_adjusted?(adjustable)
      create_adjustment(order, adjustable, promotion_code)
    end

    def create_unique_adjustments(order, adjustables, promotion_code)
      adjustables.where.not(id: already_adjusted_ids(order)).map do |adjustable|
        create_adjustment(order, adjustable, promotion_code) if !block_given? || yield(adjustable)
      end.any?
    end

    private

    def already_adjusted_ids(order)
      adjustments.where(order: order).pluck(:adjustable_id)
    end

    def already_adjusted?(adjustable)
      adjustments.where(adjustable: adjustable).exists?
    end

    def deals_with_adjustments_for_deleted_source
      # For incomplete orders, remove the adjustment completely.
      adjustments.for_incomplete_order.destroy_all

      # For complete orders, the source will be invalid.
      # Therefore we nullify the source_id, leaving the adjustment in place.
      # This would mean that the order's total is not altered at all.
      adjustments.for_complete_order.update_all(source_id: nil, updated_at: Time.current)
    end
  end
end
