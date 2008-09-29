class Taxonomy < ActiveRecord::Base
  has_many :taxons, :dependent => :destroy    
  has_one :root, :class_name => 'Taxon', :conditions => "parent_id is null"

end
