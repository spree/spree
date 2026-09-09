FactoryBot.define do
  factory :consent_record, class: Spree::ConsentRecord do
    store { Spree::Store.default || create(:store) }
    owner { create(:customer) }
    purpose { Spree::ConsentRecord::TERMS_OF_SERVICE }
    source { 'registration' }
    accepted { true }
    email { owner.try(:email) }
  end
end
