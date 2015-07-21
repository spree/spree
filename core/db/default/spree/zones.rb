eu_vat = Spree::Zone.create!(name: "EU_VAT", description: "Countries that make up the EU VAT zone.")
north_america = Spree::Zone.create!(name: "North America", description: "USA + Canada")
%w(PL FI PT RO DE FR SK HU SI IE AT ES IT BE SE LV BG GB LT CY LU MT DK NL EE).
each do |name|
  eu_vat.zone_members.create!(zoneable: Spree::Country.find_by!(iso: name))
end

%w(US CA).each do |name|
  north_america.zone_members.create!(zoneable: Spree::Country.find_by!(iso: name))
end


