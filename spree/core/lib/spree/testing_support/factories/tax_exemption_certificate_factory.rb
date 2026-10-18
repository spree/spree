FactoryBot.define do
  factory :tax_exemption_certificate, class: Spree::TaxExemptionCertificate do
    company
    sequence(:certificate_number) { |n| "CERT-#{n}" }
    status { 'pending' }

    transient do
      reason_code { 'RESALE' }
    end

    # A certificate may only record a reason its store offers, so the reason
    # is found or created in the company's store for whichever code a spec
    # picks.
    tax_exemption_reason do
      company.store.tax_exemption_reasons.find_or_create_by!(code: reason_code.to_s.upcase) do |reason|
        reason.name = reason_code.to_s.humanize
      end
    end

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
