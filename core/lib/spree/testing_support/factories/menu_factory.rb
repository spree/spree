FactoryBot.define do
  factory :menu, class: Spree::Menu do
    name { generate(:random_string) }
    locale { 'en' }
    location {'Header'}
  end
end
