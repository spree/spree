Factory.sequence(:taxon_sequence) {|n| "Taxon ##{n}"}

Factory.define(:taxon) do |record|
  record.name { Factory.next(:taxon_sequence) } 

  # associations: 
  record.association(:taxonomy, :factory => :taxonomy)
  record.association(:parent, :factory => :root_taxon)
end

Factory.define(:root_taxon, :class=>Taxon) do |record|
  record.name { Factory.next(:taxon_sequence) }

  # associations:
  record.association(:taxonomy, :factory => :taxonomy)
end
