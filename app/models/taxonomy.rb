class Taxonomy < ActiveRecord::Base
  has_many :taxons, :dependent => :destroy    
  
  def root
    Taxon.roots.find { |root| root.taxonomy_id == id }
  end
end
