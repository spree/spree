class Taxon < ActiveRecord::Base
  acts_as_nested_set :dependent => :destroy

  belongs_to :taxonomy
  has_and_belongs_to_many :products
  before_create :set_permalink
  before_save :ensure_trailing_slash

  validates :name, :presence => true
  has_attached_file :icon,
                :styles => { :mini => '32x32>', :normal => '128x128>' },
                :default_style => :mini,
                :url => "/assets/taxons/:id/:style/:basename.:extension",
                :path => ":rails_root/public/assets/taxons/:id/:style/:basename.:extension",
                :default_url => "/images/default_taxon.png"

  # indicate which filters should be used for a taxon
  # this method should be customized to your own site
  include ::ProductFilters  # for detailed defs of filters
  def applicable_filters
    fs = []
    # fs << ProductFilters.taxons_below(self)
    ## unless it's a root taxon? left open for demo purposes
    
    fs << ProductFilters.price_filter if ProductFilters.respond_to?(:price_filter)
    fs << ProductFilters.brand_filter if ProductFilters.respond_to?(:brand_filter)
    fs
  end

  # Creates permalink based on .to_url method provided by stringx gem
  def set_permalink
    if parent_id.nil?
      self.permalink = name.to_url + "/" if self.permalink.blank?
    else
      parent_taxon = Taxon.find(parent_id)
      self.permalink = parent_taxon.permalink + (self.permalink.blank? ? name.to_url : self.permalink.split("/").last) + "/"
    end
  end

  private
  # obsolete, kept for backwards compat
  def escape(str)
    str.blank? ? "" : str.to_url
  end

  def ensure_trailing_slash
    set_permalink if self.permalink.blank?
    self.permalink += "/" unless self.permalink[-1..-1] == "/"
  end
end
