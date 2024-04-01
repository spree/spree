ukraine_zone = Spree::Zone.where(name: 'Україна').first_or_create!
ukraine_states = Spree::Country.find_by!(iso: 'UA').states
ukraine_states.each do |state|
    ukraine_zone.zone_members.where(zoneable: state).first_or_create!
end
