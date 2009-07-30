Factory.define :coupon do |f|
  f.code "FOO"
  f.combine true
  f.calculator {|r| Factory(:calculator, :calculable => r.instance_eval{@instance}) }
end
