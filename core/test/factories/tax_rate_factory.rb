Factory.define(:tax_rate) do |f|
  f.amount 10.0
  f.tax_category {|r| r.association(:tax_category)}
end