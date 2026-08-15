FactoryBot.define do
  # Like countries, subdivisions are reference data rather than records. The
  # sequence walks the country's own subdivisions so several states of one
  # country stay distinct.
  factory :state, class: Spree::State do
    transient do
      sequence(:subdivision_index) { |n| n }
      country { Spree::Country.by_iso('US') }
    end

    country_code { country&.iso }

    abbr do
      codes = country_code ? Spree::IsoData.subdivisions(country_code).keys : []
      codes.any? ? codes[subdivision_index % codes.size] : nil
    end

    name { (country_code && abbr && Spree::IsoData.subdivision_name(country_code, abbr)) || abbr }

    skip_create
    initialize_with { Spree::State.new(abbr: abbr, name: name, country_code: country_code) }
  end
end
