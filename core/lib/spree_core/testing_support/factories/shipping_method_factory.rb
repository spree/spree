Factory.define :shipping_method do |f|
  f.zone {|a| Zone.find_by_name("GlobalZone") || a.association(:global_zone) }
  f.name 'UPS Ground'
  f.calculator { |sm| Factory(:calculator, :calculable_id => sm.object_id, :calculable_type => "ShippingMethod") }
end

Factory.define :free_shipping_method, :class => ShippingMethod do |f|
  f.zone {|a| Zone.find_by_name("GlobalZone") || a.association(:global_zone) }
  f.name 'UPS Ground'
  f.calculator { |sm| Factory(:no_amount_calculator, :calculable_id => sm.object_id, :calculable_type => "ShippingMethod") }
end
