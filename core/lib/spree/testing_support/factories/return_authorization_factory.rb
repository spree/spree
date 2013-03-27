FactoryGirl.define do
  factory :return_authorization, :class => Spree::ReturnAuthorization do
    number '100'
    amount 100.00
    order { FactoryGirl.create(:shipped_order) }
    reason 'no particular reason'
    state 'received'
  end
end
