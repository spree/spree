# Fixtures were created for acts_as_adjency_list, but now we have nested set, so we need to rebuild it after import
Taxon.rebuild!
Taxon.all.each{|t| t.send(:set_permalink); t.save}
