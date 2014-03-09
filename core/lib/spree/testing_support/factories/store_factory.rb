FactoryGirl.define do
  factory :store, class: Spree::Store do
    name 'Spree Test STore'
    url 'localhost:3000'
    mail_from_address 'spree@example.org'
  end
end
