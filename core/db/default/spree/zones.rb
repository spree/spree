eu_vat = Spree::Zone.where(name: 'EU_VAT', description: 'Countries that make up the EU VAT zone.', kind: 'country').first_or_create!
north_america = Spree::Zone.where(name: 'North America', description: 'USA + Canada', kind: 'country').first_or_create!

%w(PL FI PT RO DE FR SK HU SI IE AT ES IT BE SE LV BG GB LT CY LU MT DK NL EE HR CZ GR).each do |name|
  eu_vat.zone_members.where(zoneable: Spree::Country.find_by!(iso: name)).first_or_create!
end

%w(US CA).each do |name|
  north_america.zone_members.where(zoneable: Spree::Country.find_by!(iso: name)).first_or_create!
end
