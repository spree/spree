
class UpgradeTaxons < ActiveRecord::Migration
  def self.up
    Taxonomy.find(:all).each do |taxonomy|
        next if (taxonomy.taxons.find_by_parent_id(nil))
        taxon = Taxon.new(:name => taxonomy.name, :taxonomy_id => taxonomy.id, :position => 1 )
        taxon.save
    end
  end

  def self.down
  end

end
