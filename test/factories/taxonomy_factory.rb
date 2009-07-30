Factory.sequence(:taxonomy_sequence) {|n| "Taxonomy ##{n}"}

Factory.define(:taxonomy) do |record|
  record.name { Factory.next(:taxonomy_sequence) } 
end