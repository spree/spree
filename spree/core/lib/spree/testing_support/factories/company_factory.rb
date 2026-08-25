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

  factory :company_address, class: Spree::CompanyAddress do
    company
    address
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
