FactoryBot.define do
  factory :company, class: Spree::Company do
    sequence(:name) { |n| "Acme Corp #{n}" }
    store { Spree::Store.default || create(:store) }
    kind { 'company' }

    factory :company_division do
      sequence(:name) { |n| "Division #{n}" }
      kind { 'division' }
      parent { association(:company, store: store) }
    end
  end

  # A company node's address book entry: an ordinary address the node owns.
  factory :company_address, parent: :address do
    association :owner, factory: :company
    first_name { nil }
    last_name  { nil }
    sequence(:label) { |n| "Site #{n}" }
  end

  factory :company_membership, class: Spree::CompanyMembership do
    company
    customer
  end

  factory :company_invitation, class: Spree::CompanyInvitation do
    company
    sequence(:email) { |n| "buyer#{n}@example.com" }
  end
end
