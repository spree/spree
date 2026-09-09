FactoryBot.define do
  factory :data_request, class: Spree::DataRequest do
    store { Spree::Store.default || create(:store) }
    customer { create(:customer) }
    kind { Spree::DataRequest::ACCESS }
    email { customer.email }

    trait :erasure do
      kind { Spree::DataRequest::ERASURE }
    end

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end
  end
end
