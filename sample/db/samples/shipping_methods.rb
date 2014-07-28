begin
center_zone = Spree::Zone.find_by_name!("מרכז")
rescue ActiveRecord::RecordNotFound
  puts "Couldn't find 'מרכז' zone. Did you run `rake db:seed` first?"
  puts "That task will set up the countries, states and zones required for Spree (This is a custom Doorstep build)."
  exit
end

north_zone = Spree::Zone.find_by_name!("צפון")
south_zone = Spree::Zone.find_by_name!("דרום")
shipping_category = Spree::ShippingCategory.find_or_create_by!(name: 'ברירת מחדל')

Spree::ShippingMethod.create!([
  {
    :name => "משלוח רגיל",
    :zones => [north_zone, center_zone, south_zone],
    :calculator => Spree::Calculator::Shipping::FlatRate.create!,
    :shipping_categories => [shipping_category]
  },
  {
    :name => "משלוח מהיר",
    :zones => [center_zone],
    :calculator => Spree::Calculator::Shipping::FlatRate.create!,
    :shipping_categories => [shipping_category]
  }
])

{
  "משלוח רגיל" => [5, "NIS"],
  "משלוח מהיר" => [5, "NIS"]
}.each do |shipping_method_name, (price, currency)|
  shipping_method = Spree::ShippingMethod.find_by_name!(shipping_method_name)
  shipping_method.calculator.preferences = {
    amount: price,
    currency: currency
  }
  shipping_method.calculator.save!
  shipping_method.save!
end

