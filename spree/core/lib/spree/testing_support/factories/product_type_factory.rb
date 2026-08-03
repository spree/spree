FactoryBot.define do
  factory :product_type, aliases: [:prototype], class: Spree::ProductType do
    name  { 'Baseball Cap' }
    store { Spree::Store.find_by(default: true) || association(:store) }
  end

  factory :product_type_with_option_types, aliases: [:prototype_with_option_types], class: Spree::ProductType do
    name         { 'Baseball Cap' }
    store        { Spree::Store.find_by(default: true) || association(:store) }
    option_types { [build(:option_type)] }
  end
end
