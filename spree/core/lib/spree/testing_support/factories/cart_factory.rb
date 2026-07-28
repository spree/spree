FactoryBot.define do
  factory :cart, class: Spree::Cart do
    store { Spree::Store.find_by(default: true) || association(:store) }
    currency { 'USD' }
  end
end
