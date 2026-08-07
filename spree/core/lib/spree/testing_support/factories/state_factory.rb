FactoryBot.define do
  # Like countries, subdivisions are reference data rather than records. The
  # sequence walks the country's own subdivisions so several states of one
  # country stay distinct.
  factory :state, class: Spree::State do
    transient do
      sequence(:subdivision_index) { |n| n }
      country { Spree::Country.by_iso('US') }
    end

    country_iso { country&.iso }

    abbr do
      codes = country_iso ? Spree::IsoData.subdivisions(country_iso).keys : []
      codes.any? ? codes[subdivision_index % codes.size] : nil
    end

    name { (country_iso && abbr && Spree::IsoData.subdivision_name(country_iso, abbr)) || abbr }

    skip_create
    initialize_with { Spree::State.new(abbr: abbr, name: name, country_iso: country_iso) }
  end
end
