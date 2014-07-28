north = Spree::Zone.create!(name: "צפון"), description: "איזור חלוקה צפוני.")
center = Spree::Zone.create!(name: "מרכז"), description: "איזור חלוקה מרכזי.")
south = Spree::Zone.create!(name: "דרום"), description: "איזור חלוקה דרומי.")

['חיפה והצפון'].
each do |name|
  north.zone_members.create!(zoneable: Spree::Country.find_by!(name: name))
end

['ירושלים', 'תל אביב והמרכז'].
each do |name|
  center.zone_members.create!(zoneable: Spree::Country.find_by!(name: name))
end
    
['שפלה והדרום'].
each do |name|
  south.zone_members.create!(zoneable: Spree::Country.find_by!(name: name))
end




