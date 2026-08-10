FactoryBot.define do
  factory :tax_exemption_certificate, class: Spree::TaxExemptionCertificate do
    company
    sequence(:certificate_number) { |n| "CERT-#{n}" }
    reason_code { 'resale' }
    status { 'pending' }

    trait :verified do
      status { 'verified' }
      verified_at { Time.current }
    end

    trait :expired do
      status { 'verified' }
      expires_at { 1.day.ago }
    end
  end
end
