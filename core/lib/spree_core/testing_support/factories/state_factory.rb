Factory.define :state do |f|
  f.name 'ALABAMA'
  f.abbr 'AL'
  f.country { |country| country.association(:country) }
end
