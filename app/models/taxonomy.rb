class Taxonomy < ActiveRecord::Base
  has_many :taxons
  
  def root
    Taxon.roots.find { |root| root.taxonomy_id == id }
  end
end
