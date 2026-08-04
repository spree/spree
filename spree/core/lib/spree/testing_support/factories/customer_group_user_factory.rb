FactoryBot.define do
  factory :customer_group_user, class: Spree::CustomerGroupUser do
    customer_group
    customer
  end
end
