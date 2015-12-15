FactoryGirl.define do
  iso2_candidates = TwitterCldr::Shared::PostalCodes
    .territories
    .reject do |code|
      # Reject territories that do not have a manadtory postal code.
      # Spree cannot handle these correctly.
      #
      # There is no nicer API in the Cldr to check for countries that
      # are guaranteed to have postcodes.
      TwitterCldr::Shared::PostalCodes
        .for_territory(code)
        .regexp.
          source.
          end_with?('?')
    end
    .map(&:to_s)
    .map(&:upcase)

  iso3_candidates = iso2_candidates.map(&'%s3'.method(:%))

  factory :country, class: Spree::Country do
    sequence(:iso_name, &'Country %d'.method(:%))
    sequence(:name,     &'Country %d'.method(:%))

    sequence(:iso)     { |n| iso2_candidates.fetch(n % iso2_candidates.length) }
    sequence(:iso3)    { |n| iso3_candidates.fetch(n % iso3_candidates.length) }
    sequence(:numcode) { |n| (n % 999).succ                                    }
  end
end
