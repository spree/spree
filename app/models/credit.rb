class Credit < Adjustment
  before_save :ensure_negative_amount

  private
  def ensure_negative_amount
    self.amount = -1 * self.amount.abs if self.amount
  end
end
