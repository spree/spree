class Taxon < ActiveRecord::Base
  acts_as_adjacency_list :foreign_key => 'parent_id', :order => 'position'
  belongs_to :taxonomy
end
