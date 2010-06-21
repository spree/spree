Factory.define :country do |f|
  f.name { Faker::Address.uk_country }
  f.iso_name {|c| "#{c.name}"}
  f.zone { Zone.global }
end