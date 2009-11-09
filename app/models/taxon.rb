class Taxon < ActiveRecord::Base
  acts_as_nested_set :dependent => :destroy

  belongs_to :taxonomy
  has_and_belongs_to_many :products
  before_save :set_permalink  
    

  # indicate which filters should be used for a taxon
  # this method should be customized to your own site
  include ::ProductFilters  # for detailed defs of filters
  def applicable_filters
    fs  = []
    fs << ProductFilters.taxons_below(self)
    ## unless it's a root taxon? left open for demo purposes
    fs += [ 
      ProductFilters.price_filter,
      ProductFilters.brand_filter,
      ProductFilters.selective_brand_filter(self) ]
  end
  
  private

  # Creates permalink based on .to_url method provided by stringx gem
  def set_permalink
		if parent_id.nil?
		  self.permalink = name.to_url + "/"
		else
		  parent_taxon = Taxon.find(parent_id) 
		  self.permalink = parent_taxon.permalink + name.to_url + "/"
		end
  end
  
  # obsolete, kept for backwards compat 
  def escape(str)
    str.blank? ? "" : str.to_url
  end
end
