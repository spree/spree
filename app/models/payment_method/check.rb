class PaymentMethod::Check < PaymentMethod

  def payment_source_class
    ::Check
  end
  
end