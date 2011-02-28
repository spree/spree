Factory.define(:taxon) do |record|
  record.name "Ruby on Rails"
  record.taxonomy { Factory(:taxonomy) }
  record.parent_id nil
end
