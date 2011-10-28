Given /^a custom shipping method exists$/ do
  Spree::ShippingMethod.delete_all
  Factory(:shipping_method, :zone => Spree::Zone.find_by_name('North America'))
end

Given /^custom next on order$/ do
  order = Spree::Order.find_by_number('R100')
  order.next!
end

Given /^custom order has a ship address$/ do
  order = Spree::Order.find_by_number('R100')
  order.ship_address = Factory(:address)
  order.save!
end

Given /^product is associated with order$/ do
  order = Spree::Order.last
  product = Factory(:product, :name => 'spree t-shirt')
  order.add_variant(product.master, 2)
  order.inventory_units.each do |iu|
    iu.update_attribute_without_callbacks('state', 'sold')
  end
end

Given /^preference settings exist$/ do
  @configuration ||= Spree::AppConfiguration.find_or_create_by_name('Default configuration')
  Spree::Preference.create(:name => 'allow_ssl_in_production', :owner => @configuration, :value => '1')
  Spree::Preference.create(:name => 'site_url', :owner => @configuration, :value => 'demo.spreecommerce.com')
  Spree::Preference.create(:name => 'allow_ssl_in_development_and_test', :owner => @configuration, :value => '0')
  Spree::Preference.create(:name => 'site_name', :owner => @configuration, :value => 'Spree Demo Site')
end

Given /^custom line items associated with products$/ do
  Spree::Order.all.each do |order|
    Factory(:line_item, :order => order)
  end
end

When /^I follow the first admin_edit_spree_order link$/ do
  order = Spree::Order.order('completed_at DESC').first
  title = "admin_edit_spree_order_#{order.id}"
  click_link(title)
end

Given /^the custom address exists for the given orders$/ do
  orders = Spree::Order.order('id ASC').all
  raise 'there should be only three ordres' unless Spree::Order.count == 3

  o = orders[0]
  address = Factory(:address, :firstname => 'john')
  o.bill_address = address
  o.ship_address = address
  o.save

  o = orders[1]
  address = Factory(:address, :firstname => 'john')
  address = Factory(:address, :firstname => 'mary')
  o.bill_address = address
  o.ship_address = address
  o.save

  o = orders[2]
  address = Factory(:address, :firstname => 'angelina')
  o.bill_address = address
  o.ship_address = address
  o.save
end
