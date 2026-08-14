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

    # Price lists could also be restricted by zone. Markets are how pricing
    # targets geography now, so each zone rule becomes a MarketRule where the
    # zone's countries exactly match one of the store's markets — the one
    # mapping that provably keeps the same buyers on the same prices. A rule
    # whose countries match no market cannot be restated without silently
    # re-scoping who pays what, so its price list is deactivated instead and
    # reported with the countries it named, for the merchant to rebuild as a
    # market. Zones naming states resolve to those states' countries.
    zone_country_ids = lambda do |zone_ids|
      members = Spree::ZoneMember.where(zone_id: zone_ids)
      country_ids = Spree::Country.where(
        id: members.where(zoneable_type: 'Spree::Country').select(:zoneable_id)
      ).ids
      state_country_ids = Spree::Country.where(
        id: Spree::State.where(
          id: members.where(zoneable_type: 'Spree::State').select(:zoneable_id)
        ).select(:country_id)
      ).ids

      (country_ids + state_country_ids).uniq.sort
    end

    rules_matched = 0
    lists_deactivated = []

    Spree::PriceRule.where(type: 'Spree::PriceRules::ZoneRule').find_each do |rule|
      stored = rule.preferences.with_indifferent_access
      zone_ids = Array(stored[:zone_ids]).reject(&:blank?)
      country_ids = zone_country_ids.call(zone_ids)

      price_list = Spree::PriceList.with_deleted.find_by(id: rule.price_list_id)
      market = if price_list && country_ids.any?
                 price_list.store.markets.find do |candidate|
                   candidate.market_countries.pluck(:country_id).uniq.sort == country_ids
                 end
               end

      if market
        rule.update_columns(
          type: 'Spree::PriceRules::MarketRule',
          preferences: stored.except(:zone_ids, :country_isos).
                       merge(market_ids: [market.id.to_s]).to_h.symbolize_keys,
          updated_at: Time.current
        )
        rules_matched += 1
      else
        # Without a matching market the restriction is unrepresentable; the
        # list must not quietly widen to every buyer, so it goes dark until
        # the merchant rebuilds the geography as a market.
        if price_list && !price_list.deleted? && price_list.status != 'inactive'
          price_list.update_columns(status: 'inactive', updated_at: Time.current)
        end
        isos = Spree::Country.where(id: country_ids).pluck(:iso).sort
        lists_deactivated << [price_list, isos]
        rule.delete
      end
    end

    puts "  Converted #{rules_matched} zone price rule(s) to market rules." if rules_matched.positive?
    if lists_deactivated.any?
      puts "  Deactivated #{lists_deactivated.size} price list(s) whose zone matched no market — " \
           'create a market for the countries, then re-add the rule and reactivate:'
      lists_deactivated.each do |list, isos|
        label = list ? "#{list.name} (#{list.id})" : 'deleted price list'
        puts "    - #{label}: #{isos.any? ? isos.join(', ') : 'no resolvable countries'}"
      end
    end
  end
end
