begin
  Spree::Zone.find_by!(name: 'North America')
rescue ActiveRecord::RecordNotFound
  puts 'Couldn\'t find \'North America\' zone. Did you run `rake db:seed` first?'
  puts 'That task will set up the countries, states and zones required for Spree.'
  exit
end

ukraine_zone = Spree::Zone.find_by!(name: 'Україна')
shipping_category = Spree::ShippingCategory.find_or_create_by!(name: 'За замовчуванням')

shipping_methods = [
  {
    name: "Кур'єр",
    zones: [ukraine_zone],
    display_on: 'both',
    shipping_categories: [shipping_category]
  },
  {
    name: "Нова Пошта",
    zones: [ukraine_zone],
    display_on: 'both',
    shipping_categories: [shipping_category]
  }
]

shipping_methods.each do |attributes|
  Spree::ShippingMethod.where(name: attributes[:name]).first_or_create! do |shipping_method|
    shipping_method.calculator = Spree::Calculator::Shipping::FlatRate.create!
    shipping_method.zones = attributes[:zones]
    shipping_method.display_on = attributes[:display_on]
    shipping_method.shipping_categories = attributes[:shipping_categories]
  end
end

{
  "Кур'єр" => [100, 'UAH'],
  "Нова Пошта" => [60, 'UAH']
}.each do |shipping_method_name, (price, currency)|
  shipping_method = Spree::ShippingMethod.find_by!(name: shipping_method_name)
  shipping_method.calculator.preferences = {
    amount: price,
    currency: currency
  }
  shipping_method.calculator.save!
  shipping_method.save!
end
