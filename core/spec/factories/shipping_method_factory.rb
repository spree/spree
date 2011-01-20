Factory.define :shipping_method do |f|
  f.zone {|a| a.association(:zone) }
  f.name 'UPS Ground'
  f.display_on :front_end
  f.after_create { |sm| Factory(:calculator, :calculable_id => sm.id, :calculable_type => "shipping_method") }
end
