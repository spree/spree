FactoryGirl.define do
  factory :return_authorization, :class => Spree::ReturnAuthorization do
    number '100'
    amount 100.00
    order { FactoryGirl.create(:completed_order_with_totals) }
    reason 'no particular reason'
    state 'received'
  end
end
