FactoryBot.define do
  factory :store, class: Spree::Store do
    sequence(:code) { |i| "spree_#{i}" }
    name 'Spree Test Store'
    url 'www.example.com'
    mail_from_address 'spree@example.org'
  end
end
