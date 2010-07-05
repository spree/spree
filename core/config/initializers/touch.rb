# Touches all classes that should be initialized when spree starts
# Surrounded with exception handling because when bootstrapping a vanilla app, bootstrap breaks if model tables don't exist

begin
  ::Adjustment
  ::Charge
  ::Credit
  ::TaxCharge
  ::ShippingCharge
  ::PromotionCredit
  ::ReturnAuthorizationCredit
rescue
  nil
end

[
  Calculator::FlatPercentItemTotal,
  Calculator::FlatRate,
  Calculator::FlexiRate,
  Calculator::PerItem,
  Calculator::SalesTax,
  Calculator::Vat,
].each{|c_model|
  begin
    c_model.register if c_model.table_exists?
  rescue Exception => e
    $stderr.puts "Error registering calculator #{c_model}"
  end
}
