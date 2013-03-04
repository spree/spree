Spree::Sample.load_sample("tax_categories")

clothing = Spree::TaxCategory.find_by_name!("Clothing")

default_attrs = {
  :description => Faker::Lorem.paragraph,
  :available_on => Time.zone.now
}

products = [
  {
    :name => "Ruby on Rails Tote",
    :tax_category => clothing,
    :price => 15.99,
    :eur_price => 14,
  },
  {
    :name => "Ruby on Rails Bag",
    :tax_category => clothing,
    :price => 22.99,
    :eur_price => 19,
  },
  {
    :name => "Ruby on Rails Baseball Jersey",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "Ruby on Rails Jr. Spaghetti",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16

  },
  {
    :name => "Ruby on Rails Ringer T-Shirt",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "Ruby Baseball Jersey",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "Apache Baseball Jersey",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "Spree Baseball Jersey",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "Spree Jr. Spaghetti",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "Spree Ringer T-Shirt",
    :tax_category => clothing,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "Spree Tote",
    :tax_category => clothing,
    :price => 15.99,
    :eur_price => 14,
  },
  {
    :name => "Spree Bag",
    :tax_category => clothing,
    :price => 22.99,
    :eur_price => 19
  },
  {
    :name => "Ruby on Rails Mug",
    :price => 13.99,
    :eur_price => 12
  },
  {
    :name => "Ruby on Rails Stein",
    :price => 16.99,
    :eur_price => 14
  },
  {
    :name => "Spree Stein",
    :price => 16.99,
    :eur_price => 14,
  },
  {
    :name => "Spree Mug",
    :price => 13.99,
    :eur_price => 12
  }
]

products.each do |product_attrs|
  eur_price = product_attrs.delete(:eur_price)
  Spree::Config[:currency] = "USD"

  default_shipping_category = Spree::ShippingCategory.find_by_name!("Default Shipping")
  product = Spree::Product.create!(default_attrs.merge(product_attrs), :without_protection => true)
  Spree::Config[:currency] = "EUR"
  product.reload
  product.price = eur_price
  product.shipping_category = default_shipping_category
  product.save!
end

Spree::Config[:currency] = "USD"
