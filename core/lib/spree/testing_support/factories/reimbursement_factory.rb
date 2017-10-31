FactoryBot.define do
  factory :reimbursement, class: Spree::Reimbursement do
    transient do
      return_items_count 1
    end

    customer_return { create(:customer_return_with_accepted_items, line_items_count: return_items_count) }

    before(:create) do |reimbursement, _evaluator|
      reimbursement.order ||= reimbursement.customer_return.order
      if reimbursement.return_items.empty?
        reimbursement.return_items = reimbursement.customer_return.return_items
      end
    end
  end
end
