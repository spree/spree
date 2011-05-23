Factory.define :state do |f|
  f.name 'ALABAMA'
  f.abbr 'AL'
  f.country do |country|
    if usa = Country.find_by_numcode(840)
      country = usa
    else
      country.association(:country)
    end
  end
end
