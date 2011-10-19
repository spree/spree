Given /^custom shipment associated with order R100$/ do
  order = Spree::Order.find_by_number('R100')
  Factory(:shipment, :order => order)
end

Given /^custom inventory units associated with order R100$/ do
  order = Spree::Order.find_by_number('R100')
  Factory(:inventory_unit, :order => order)
end
