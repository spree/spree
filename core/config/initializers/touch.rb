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
