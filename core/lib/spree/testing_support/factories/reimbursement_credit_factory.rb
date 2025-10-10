FactoryBot.define do
  factory :reimbursement_credit, class: Spree::Reimbursement::Credit do
    reimbursement

    amount { 100.00 }
  end
end
