FactoryBot.define do
  factory :integration, class: Spree::Integration do
    type { 'Spree::Integration' }
    store { Spree::Store.default }
    active { true }
  end
end
