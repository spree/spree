Given /^custom payment associated with order R100$/ do
  order = Order.find_by_number('R100')
  Factory(:payment, :order => order)
end
