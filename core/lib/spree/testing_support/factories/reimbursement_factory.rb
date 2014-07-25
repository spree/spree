FactoryGirl.define do
  factory :reimbursement, class: Spree::Reimbursement do
    association(:customer_return, factory: :customer_return_with_accepted_items)

    before(:create) do |reimbursement, evaluator|
      reimbursement.order ||= reimbursement.customer_return.order
      if reimbursement.return_items.empty?
        reimbursement.return_items = reimbursement.customer_return.return_items
      end
    end
  end
end
