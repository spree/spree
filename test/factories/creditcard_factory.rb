Factory.define(:creditcard) do |f|
  f.verification_value 123
  f.month 12
  f.year 2013
  f.number "4111111111111111"
  f.association :address
  f.association :checkout
end

Factory.define :authorized_creditcard, :parent => :creditcard do |f|
  f.creditcard_payments { [Factory(:creditcard_payment)] }
end