# special mock calculator needed for tests
class TestCouponCalc < Calculator
  def self.test_amount
    0.99
  end
  def calculate_discount(checkout)    
    self.class.test_amount
  end
end

# special mock calculator needed for tests
class TestShippingCalc < ShippingCalculator  
  def calculate_shipping(order)
    5
  end
end

Factory.define :order do |f| 
  f.charges { [Factory(:ship_charge), Factory(:tax_charge)] } 
end

Factory.define :checkout do |f|
  f.association :bill_address, :factory => :address
  f.association :ship_address, :factory => :address
  f.completed_at Time.now 
  f.association :order
end 

Factory.define :incomplete_checkout, :parent => :checkout do |f|
  f.completed_at nil
end

Factory.define :user do |f|
  f.login { Factory.next(:name) }
  f.email { Factory.next(:email) }
  f.password "spree"
  f.password_confirmation "spree"
end

Factory.define :shipment do |f|
  f.association :shipping_method 
  f.association :order
end

Factory.define :shipping_method do |f|
  f.shipping_calculator "Spree::FlatRateShipping::Calculator"
  f.association :zone
end

Factory.define :zone do |f|
  f.name { Factory.next(:name) }
end

Factory.define :address do |f|
  f.firstname "Frank"
  f.lastname "Foo"
  f.city "Fooville"
  f.address1 "99 Foo St."
  f.zipcode "12345"
  f.phone "555-555-1212"
  f.state_name "Foo Province"
  f.association :country
end

Factory.define :product do |f|
  f.name "Foo Product"
  f.master_price 19.99
  f.variants do |variants|
    [Factory(:variant, :option_values => []), variants.association(:variant)]
  end
end

Factory.define :option_value do |f| 
  f.name "Size"
  f.presentation "S"  
  f.association :option_type
end

Factory.define :option_type do |f|
  f.name "foo-size"
  f.presentation "Size"
end

Factory.define :empty_variant, :class => :Variant do |f|
  f.price 19.99
end

Factory.define :variant do |f|
  f.price 19.99
  f.option_values { [Factory(:option_value)] }  
end

Factory.define :inventory_unit do |f|
end

Factory.define :line_item do |f|
  f.quantity 2
  f.price 12.99
  f.association :variant
end

Factory.define :country do |f|
  f.name { Factory.next(:name) }
  f.iso_name {|c| "#{c.name}"}
end

Factory.sequence :name do |n|
  "Foo_#{n}"
end

Factory.sequence :email do |n|
  "foo_#{n}@example.com"
end

Factory.define :creditcard do |f|
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

Factory.define :creditcard_payment do |f|
  f.association :creditcard
  f.creditcard_txns { [Factory(:creditcard_txn, :txn_type => CreditcardTxn::TxnType::AUTHORIZE)] }
  f.association :order
end               

Factory.define :creditcard_txn do |f|
  f.amount 45.75
  f.response_code 12345
end

Factory.define :ship_charge, :class => ShippingCharge do |f|
  f.amount 8.99
  f.description "Shipping"
end

Factory.define :tax_charge, :class => TaxCharge do |f|
  f.amount 3.17
  f.description "Sales Tax"
end    

Factory.define :credit do |f|
  f.amount 2.00
  f.description "20% Off"    
  f.association :creditable, :factory => :discount    
end
                               
Factory.define :coupon_calculator, :class => TestCouponCalc do |f| 
  f.association :calculable, :factory => :coupon
end

Factory.define :coupon do |f|
  f.code "FOO"
  f.combine true 
  f.calculator { |c| Factory(:coupon_calculator, :calculable_id => c.object_id, :calculable_type => "Coupon") }
end

Factory.define :discount do |f|
  f.association :checkout
  f.association :coupon  
end                

Factory.define :shipping_method do |f|
  f.association :zone    
  f.name { Factory.next(:name) }
end

Factory.define :calculator, :class => TestShippingCalc do |f|
  f.association :calculable, :factory => :shipping_method
end