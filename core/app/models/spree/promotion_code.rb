class Spree::PromotionCode < ActiveRecord::Base
  belongs_to :promotion, inverse_of: :codes
  has_many :adjustments

  validates :value, presence: true, uniqueness: true
  validates :promotion, presence: true

  before_save :downcase_value

  # Whether the given promotable would violate the usage restrictions
  #
  # @param promotable object (e.g. order/line item/shipment)
  # @return true or false
  def usage_limit_exceeded?(promotable)
    # TODO: This logic appears to be wrong.
    # See note on Promotion#usage_limit_exceeded?
    if usage_limit
      usage_count - usage_count_for(promotable) >= usage_limit
    end
  end

  # Number of times the code has been used overall
  #
  # @return [Integer] usage count
  def usage_count
    adjustment_promotion_scope(Spree::Adjustment.eligible).count
  end

  def usage_limit
    promotion.per_code_usage_limit
  end

  private

  def usage_count_for(promotable)
    adjustment_promotion_scope(promotable.adjustments).count
  end

  def downcase_value
    self.value = value.downcase
  end

  def adjustment_promotion_scope(adjustment_scope)
    adjustment_scope.promotion.where(source_id: promotion.actions.map(&:id), promotion_code_id: id)
  end
end
