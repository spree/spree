Factory.define :country do |f|
  f.iso_name 'INDIA'
  f.name 'INDIA'
  f.iso3 'IND'
  f.numcode 356
end

Factory.define :state do |f|
  f.name 'ALABAMA'
  f.abbr 'AL'
  f.country { |country| country.association(:country) }

end

Factory.define :address do |f|
  f.firstname 'John'
  f.lastname 'Doe'
  f.address1 '10 Lovely Street'
  f.address2 'Northwest'
  f.city   "Herndon"
  f.state  { |state| state.association(:state) }
  f.zipcode '20170'
  f.country { |country| country.association(:country) }
  f.phone '123-456-7890'
  f.state_name "maryland"
  f.alternative_phone "123-456-7899"
end
