class Credit < Adjustment
   before_save :inverse_amount

  def inverse_amount
    x = self.amount > 0 ? -1 : 1
    self.amount = self.amount * x
  end

  def calculate_adjustment
    adjustment = super
    adjustment && (
      x = adjustment > 0 ? -1 : 1
      adjustment * x
    )
  end
end
