class Charge < Adjustment
  before_save :ensure_positive_amount

  private
  def ensure_positive_amount
    self.amount = self.amount.abs if self.amount
  end

  def self.subclasses
    self == Charge ? [TaxCharge, ShippingCharge] : []
  end

end