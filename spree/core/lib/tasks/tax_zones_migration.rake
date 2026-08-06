namespace :spree do
  desc <<~DESC
    Converts the zones tax rates were configured against into direct
    country/state references (Spree 6.0). A zone spanning several countries
    becomes one rate per country, since a rate can now name only one
    jurisdiction — which is what lets a tax line report the country that taxed
    it. Idempotent: rates that already carry a country or state are skipped, and
    so are rates whose zone had no members, which stay as "everywhere" rates.
  DESC
  task migrate_tax_zones: :environment do
    # One entry per taxing jurisdiction in the zone. State members carry their
    # own country, so a mixed zone still yields complete pairs.
    jurisdictions_for = lambda do |zone|
      zone.zone_members.filter_map do |member|
        case member.zoneable_type
        when 'Spree::Country'
          { country_id: member.zoneable_id, state_id: nil }
        when 'Spree::State'
          state = Spree::State.find_by(id: member.zoneable_id)
          { country_id: state.country_id, state_id: state.id } if state
        end
      end.uniq
    end

    converted = 0
    duplicated = 0
    skipped = 0

    Spree::TaxRate.with_deleted.
      where(country_id: nil, state_id: nil).where.not(zone_id: nil).find_each do |rate|
      zone = Spree::Zone.find_by(id: rate.zone_id)
      jurisdictions = zone ? jurisdictions_for.call(zone) : []

      if jurisdictions.empty?
        skipped += 1
        next
      end

      first, *rest = jurisdictions
      rate.update_columns(country_id: first[:country_id], state_id: first[:state_id], updated_at: Time.current)
      converted += 1

      rest.each do |jurisdiction|
        Spree::TaxRate.insert(
          rate.attributes.slice(*Spree::TaxRate.column_names).except('id', 'created_at', 'updated_at').merge(
            'country_id' => jurisdiction[:country_id],
            'state_id' => jurisdiction[:state_id],
            'created_at' => Time.current,
            'updated_at' => Time.current
          )
        )
        duplicated += 1
      end
    end

    puts "  Converted #{converted} tax rates, split #{duplicated} extra rate(s) off multi-jurisdiction zones, " \
         "skipped #{skipped}."
  end
end
