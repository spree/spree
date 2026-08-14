FactoryBot.define do
  factory :company, class: Spree::Company do
    sequence(:name) { |n| "Acme Corp #{n}" }
    store { Spree::Store.default || create(:store) }

    factory :company_with_location do
      after(:create) do |company|
        create(:company_location, company: company)
      end
    end
  end

  factory :company_location, class: Spree::CompanyLocation do
    company
    sequence(:name) { |n| "Branch #{n}" }
  end

  factory :company_contact, class: Spree::CompanyContact do
    company_location
    customer
  end
end
