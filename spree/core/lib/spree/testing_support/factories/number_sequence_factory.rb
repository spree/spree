FactoryBot.define do
  factory :number_sequence, class: 'Spree::NumberSequence' do
    store { Spree::Store.default }
    resource_type { 'order' }
    value { 1000 }
  end
end
