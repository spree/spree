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

