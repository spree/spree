Factory.define :address do |f|
  f.firstname 'John'
  f.lastname 'Doe'
  f.address1 '10 Lovely Street'
  f.address2 'Northwest'
  f.city   "Herndon"
  f.zipcode '20170'
  f.phone '123-456-7890'
  f.alternative_phone "123-456-7899"

  f.state  { |address| address.association(:state) }
  f.country do |address|
    if address.state
      address.state.country
    else
      address.association(:country)
    end
  end
end

