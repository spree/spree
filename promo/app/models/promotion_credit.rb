class PromotionCredit < ::Adjustment
  scope :with_order, :conditions => "order_id IS NOT NULL"

  # Checks if credit is still applicable to order
  # If source of adjustment is credit, it checks if it's still valid
  def applicable?
    source && source.eligible?(order) && super
  end
end