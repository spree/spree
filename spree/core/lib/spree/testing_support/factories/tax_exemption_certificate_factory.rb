FactoryBot.define do
  factory :tax_exemption_certificate, class: Spree::TaxExemptionCertificate do
    company
    sequence(:certificate_number) { |n| "CERT-#{n}" }
    reason_code { 'resale' }
    status { 'pending' }

    # A certificate may only record a reason its store offers, so the reason
    # is created alongside whichever code a spec picks.
    after(:build) do |certificate|
      store = certificate.company&.store
      next if store.nil? || certificate.reason_code.blank?

      store.tax_exemption_reasons.find_or_create_by!(code: certificate.reason_code) do |reason|
        reason.name = certificate.reason_code.humanize
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
