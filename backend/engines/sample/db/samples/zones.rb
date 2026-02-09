california_zone = Spree::Zone.where(name: 'California Tax', description: 'California tax zone', kind: 'state').first_or_create!
california_state = Spree::Country.find_by!(iso3: 'USA').states.find_by(abbr: 'CA')
california_zone.zone_members.where(zoneable: california_state).first_or_create!
