eu_vat = Spree::Zone.where(name: 'EU_VAT', description: 'Countries that make up the EU VAT zone.', kind: 'country').first_or_create!
north_america = Spree::Zone.where(name: 'North America', description: 'USA + Canada', kind: 'country').first_or_create!
south_america = Spree::Zone.where(name: 'South America', description: 'South America', kind: 'country').first_or_create!
middle_east = Spree::Zone.where(name: 'Middle East', description: 'Middle East', kind: 'country').first_or_create!
asia = Spree::Zone.where(name: 'Asia', description: 'Asia', kind: 'country').first_or_create!

%w(PL FI PT RO DE FR SK HU SI IE AT ES IT BE SE LV BG GB LT CY LU MT DK NL EE HR CZ GR).each do |name|
  eu_vat.zone_members.where(zoneable: Spree::Country.find_by!(iso: name)).first_or_create!
end

%w(US CA).each do |name|
  north_america.zone_members.where(zoneable: Spree::Country.find_by!(iso: name)).first_or_create!
end

%w(BH CY EG IR IQ IL JO KW LB OM QA SA SY TR AE YE).each do |name|
  middle_east.zone_members.where(zoneable: Spree::Country.find_by!(iso: name)).first_or_create!
end

%w(AF AM AZ BH BD BT BN KH CN CX CC IO GE HK IN ID IR IQ IL JP JO KZ KW KG LA LB MO MY MV MN MM NP
  KP OM PK PS PH QA SA SG KR LK SY TW TJ TH TR TM AE UZ VN YE).each do |name|
  asia.zone_members.where(zoneable: Spree::Country.find_by!(iso: name)).first_or_create!
end

%w(AR BO BR CL CO EC FK GF GY PY PE SR UY VE).each do |name|
  south_america.zone_members.where(zoneable: Spree::Country.find_by!(iso: name)).first_or_create!
end
