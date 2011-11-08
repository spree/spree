class RemoveTrailingSlashesInTaxonPermalinks < ActiveRecord::Migration
  def up
    taxons = select_all "SELECT * FROM taxons"
    taxons.each do |taxon|
      if taxon['permalink'] && taxon['permalink'][-1..-1] == '/'
        execute "UPDATE taxons SET permalink = '#{taxon['permalink'][0...-1]}' WHERE id = #{taxon['id']}"
      end
    end
  end

  def down
    taxons = select_all "SELECT * FROM taxons"
    taxons.each do |taxon|
      if taxon['permalink'] && taxon['permalink'][-1..-1] != '/'
        execute "UPDATE taxons SET permalink = '#{taxon['permalink'] + '/'}' WHERE id = #{taxon['id']}"
      end
    end
  end
end
