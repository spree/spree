module Spree
  module Seeds
    class Zones
      prepend Spree::ServiceModule::Base

      def call
        eu_vat = Spree::Zone.where(name: 'EU_VAT', description: 'Countries that make up the EU VAT zone.', kind: 'country').first_or_create!
        uk_vat = Spree::Zone.where(name: 'UK_VAT', kind: 'country').first_or_create!
        north_america = Spree::Zone.where(name: 'North America', description: 'USA + Canada', kind: 'country').first_or_create!
        central_america_and_caribbean = Spree::Zone.where(name: 'Central America and Caribbean', description: 'Central America and Caribbean', kind: 'country').first_or_create!
        south_america = Spree::Zone.where(name: 'South America', description: 'South America', kind: 'country').first_or_create!
        middle_east = Spree::Zone.where(name: 'Middle East', description: 'Middle East', kind: 'country').first_or_create!
        africa = Spree::Zone.where(name: 'Africa', description: 'Africa', kind: 'country').first_or_create!
        asia = Spree::Zone.where(name: 'Asia', description: 'Asia', kind: 'country').first_or_create!
        australia_and_oceania = Spree::Zone.where(name: 'Australia and Oceania', description: 'Australia and Oceania', kind: 'country').first_or_create!

        create_zone_members(eu_vat, %w(PL FI PT RO DE FR SK HU SI IE AT ES IT BE SE LV BG LT CY LU MT DK NL EE HR CZ GR))
        create_zone_members(north_america, %w(US CA))
        create_zone_members(central_america_and_caribbean, %w(MX GT BZ SV HN NI CR PA CU DO HT JM BS BB TT PR AG DM GD KN LC VC AI AW BM KY CW GP MQ MS BL MF SX TC VG VI))
        create_zone_members(south_america, %w(AR BO BR CL CO EC FK GF GY PY PE SR UY VE))
        create_zone_members(middle_east, %w(BH CY EG IR IQ IL JO KW LB OM QA SA SY TR AE YE))
        create_zone_members(africa, %w(DZ AO BJ BW BF BI CV CM CF TD KM CG CD CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS LR LY
                                       MG MW ML MR MU YT MA MZ NA NE NG RE RW SH ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW))
        create_zone_members(asia, %w(AF AM AZ BH BD BT BN KH CN CX CC GE HK IN ID IR IQ IL JP JO KZ KW KG LA LB MO MY MV MN MM NP
                                     KP OM PK PS PH QA SA SG KR LK SY TW TJ TH TR TM AE UZ VN YE))
        create_zone_members(australia_and_oceania, %w(AU NZ PG FJ SB VU NC PF WS AS GU KI MH FM NR NU NF MP PW PN TK TO TV WF CK))
        uk_vat.zone_members.where(zoneable: Spree::Country.find_by(iso: 'GB')).first_or_create!
      end

      protected

      def create_zone_members(zone, country_codes)
        countries_ids = Spree::Country.where(iso: country_codes).ids
        existing_ids = zone.zone_members.where(zoneable_type: 'Spree::Country', zoneable_id: countries_ids).pluck(:zoneable_id)
        new_ids = countries_ids - existing_ids

        return if new_ids.empty?

        zone_members = new_ids.map do |country_id|
          {
            zoneable_id: country_id,
            zoneable_type: 'Spree::Country',
            zone_id: zone.id,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        Spree::ZoneMember.insert_all(zone_members)
      end
    end
  end
end
