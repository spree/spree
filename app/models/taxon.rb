class Taxon < ActiveRecord::Base
  acts_as_adjacency_list :foreign_key => 'parent_id', :order => 'position'
  belongs_to :taxonomy
  has_and_belongs_to_many :products
  before_save :set_permalink  
    
  private

  # Creates permalink based on .to_url method provided by stringx gem
  def set_permalink
    self.permalink = (ancestors.reverse + [self]).collect { |taxon| 
      taxon.name.to_url 
    }.join("/") + "/"
  end
  
  # obsolete, kept for backwards compat 
  def escape(str)
    str.blank? ? "" : str.to_url
  end
end
