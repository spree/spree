FactoryBot.define do
  # States are reference data too: the code has to be a real subdivision of the
  # country, since that is what address validation and zone matching check
  # against. The sequence walks the country's own subdivisions so several
  # states of one country stay distinct.
  factory :state, class: Spree::State do
    transient do
      sequence(:subdivision_index) { |n| n }
    end

    country { Spree::Country.find_by(iso: 'US') || create(:country_us) }

    # Specs pass `country: nil` to exercise a stateless address, so both of
    # these have to tolerate having no country to look subdivisions up in.
    abbr do
      codes = country ? Spree::IsoData.subdivisions(country.iso).keys : []
      codes.any? ? codes[subdivision_index % codes.size] : "S#{subdivision_index}"
    end

    name { (country && Spree::IsoData.subdivision_name(country.iso, abbr)) || abbr }

    # `[country_id, abbr]` is uniquely indexed, and a country's subdivisions are
    # fixed data every spec draws from the same pool — so reuse the row.
    initialize_with do
      Spree::State.find_or_initialize_by(country_id: country&.id, abbr: abbr).tap do |state|
        state.name ||= name
      end
    end
  end
end
