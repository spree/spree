Factory.define :tax_rate do |f|
  f.zone { Factory(:zone) }
  f.amount 100.00
  f.tax_category { Factory(:tax_category) }
end
