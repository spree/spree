FactoryBot.define do
  factory :external_reference, class: Spree::ExternalReference do
    store { Spree::Store.default || create(:store) }
    resource { create(:product, store: store) }
    system { 'erp' }
    sequence(:external_id) { |n| "EXT-#{n}" }
  end
end
