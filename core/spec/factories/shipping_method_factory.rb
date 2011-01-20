Factory.define :shipping_method do |f|
  f.zone {|a| a.association(:zone) }
  f.name 'UPS Ground'
  f.display_on :front_end
  f.calculator {|a| a.association(:calculator, :calculable_id => id, :calculable_type => "shipping_method") }
end
