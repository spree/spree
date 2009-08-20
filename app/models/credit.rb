class Credit < Adjustment
   before_save :inverse_amount

  def calculate_adjustment
    if adjustment_source
      case adjustment_source_type
      when "Coupon"
       calculate_coupon_credit
      else
        super
      end
    end
  end
   
  def inverse_amount
    x = self.amount > 0 ? -1 : 1
    self.amount = self.amount * x
  end
  
  private 
  def calculate_coupon_credit
    adjustment_source.calculator.compute(order)    
  end
end
