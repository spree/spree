FactoryGirl.define do
  factory :store, class: Spree::Store do
    sequence(:code,              &'spree_%d'.method(:%))
    sequence(:name,              &'Spree Test Store %d'.method(:%))
    sequence(:url,               &'www%d.example.com'.method(:%))
    sequence(:mail_from_address, &'spree%d@example.org'.method(:%))
  end
end
