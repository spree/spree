class Credit < Adjustment
  before_save :ensure_negative_amount

  private
  # Ensures Charge always has negative amount.
  #
  # Amount shold be modified ONLY when it's going to be saved to the database
  # (read_attribute returns value)
  #
  # WARNING! It does not protect from Credits getting positive amounts while
  # amount is autocalculated! Descending classes should ensure amount is always
  # negative in their calculate_adjustment methods
  # This method should be threated as a last resort for keeping integrity of adjustments
  def ensure_negative_amount
    if (db_amount = read_attribute(:amount)) && db_amount > 0
      self.amount *= -1
    end
  end
end
