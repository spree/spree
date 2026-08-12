namespace :spree do
  desc <<~DESC
    Converts the zones tax rates were configured against into the country and
    state codes a rate now carries (Spree 6.0). A zone spanning several
    countries becomes one rate per country, since a rate can name only one
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
          country = Spree::Country.find_by(id: member.zoneable_id)
          { country_iso: country.iso, state_code: nil } if country
        when 'Spree::State'
          state = Spree::State.find_by(id: member.zoneable_id)
          { country_iso: state.country&.iso, state_code: state.abbr } if state&.country
        end
      end.uniq
    end

    converted = 0
    duplicated = 0
    skipped = 0

    Spree::TaxRate.with_deleted.
      where(country_iso: nil, state_code: nil).where.not(zone_id: nil).find_each do |rate|
      zone = Spree::Zone.find_by(id: rate.zone_id)
      jurisdictions = zone ? jurisdictions_for.call(zone) : []

      if jurisdictions.empty?
        skipped += 1
        next
      end

      first, *rest = jurisdictions

      # One rate's split is all-or-nothing. Stamping the source before the copies
      # exist means an interrupted run leaves a converted rate whose other
      # jurisdictions were never created — and the next run skips it, because it
      # now carries a country. The merchant would be short a rate with nothing
      # saying so.
      ApplicationRecord.transaction do
        rate.update_columns(country_iso: first[:country_iso], state_code: first[:state_code], updated_at: Time.current)

        rest.each do |jurisdiction|
          Spree::TaxRate.insert(
            rate.attributes.slice(*Spree::TaxRate.column_names).except('id', 'created_at', 'updated_at').merge(
              'country_iso' => jurisdiction[:country_iso],
              'state_code' => jurisdiction[:state_code],
              'created_at' => Time.current,
              'updated_at' => Time.current
            )
          )
        end
      end

      converted += 1
      duplicated += rest.size
    end

    puts "  Converted #{converted} tax rates, split #{duplicated} extra rate(s) off multi-jurisdiction zones, " \
         "skipped #{skipped}."

    # Price lists could also be restricted by zone. Those rules now decide by
    # country, so restate each one as the countries its zones contained. A
    # zone that named individual states becomes those states' countries, which
    # widens the rule — reported below so the merchant can narrow it by hand.
    # Both lists resolve through their model on the way out, so a member
    # pointing at a deleted country or state drops out instead of being written
    # back as a code nothing issued.
    countries_for = lambda do |zone_ids|
      members = Spree::ZoneMember.where(zone_id: zone_ids)
      country_isos = Spree::Country.where(
        id: members.where(zoneable_type: 'Spree::Country').pluck(:zoneable_id)
      ).pluck(:iso)
      state_country_isos = Spree::Country.where(
        id: Spree::State.where(
          id: members.where(zoneable_type: 'Spree::State').pluck(:zoneable_id)
        ).select(:country_id)
      ).pluck(:iso)

      [(country_isos + state_country_isos).compact.uniq.map(&:upcase), state_country_isos.any?]
    end

    rules_converted = 0
    rules_widened = 0
    rules_unrestricted = 0

    Spree::PriceRules::ZoneRule.find_each do |rule|
      stored = rule.preferences.with_indifferent_access
      zone_ids = Array(stored[:zone_ids]).reject(&:blank?)
      next if stored[:country_isos].present? || zone_ids.empty?

      country_isos, from_states = countries_for.call(zone_ids)
      rule.update_columns(
        preferences: stored.except(:zone_ids).merge(country_isos: country_isos).to_h.symbolize_keys,
        updated_at: Time.current
      )
      rules_converted += 1
      rules_widened += 1 if from_states
      # A zone that was deleted, or had no members, leaves nothing to restrict
      # by, so the rule stops narrowing its price list at all. Called out
      # because it is the one outcome here a merchant would not predict.
      rules_unrestricted += 1 if country_isos.empty?
    end

    puts "  Restated #{rules_converted} zone price rule(s) as countries " \
         "(#{rules_widened} widened from state-level zones — review those price lists)."
    if rules_unrestricted.positive?
      puts "  #{rules_unrestricted} of them named zones that no longer resolve to any country, so " \
           'those price lists now apply everywhere — set their countries by hand.'
    end
  end
end
