namespace :spree do
  desc "Resets all taxon permalinks"
  task :reset_taxon_permalinks => :environment do
    Spree::Taxon.where(:parent_id => nil).each {|taxon| redo_permalinks(taxon) }
  end

  def redo_permalinks(taxon)
    taxon.permalink = nil
    puts "#{taxon.permalink} => #{taxon.set_permalink}"
    taxon.save

    taxon.children.each { |t| redo_permalinks(t) }
  end
end 
