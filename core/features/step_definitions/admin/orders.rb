Given /^2 custom orders$/ do
  Factory(:order, :completed_at => Time.now)
  Factory(:order, :completed_at => 1.year.ago)
end

Given /^a product exists with a sku of "a100"$/ do
  Factory(:product, :sku => 'a100')
end
