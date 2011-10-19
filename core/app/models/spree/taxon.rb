class Spree::Taxon < ActiveRecord::Base
  acts_as_nested_set :dependent => :destroy

  belongs_to :taxonomy, :class_name => 'Spree::Taxonomy'
  has_and_belongs_to_many :products, :class_name => 'Spree::Product',
                                     :join_table => 'spree_products_taxons'
  before_create :set_permalink

  validates :name, :presence => true
  has_attached_file :icon,
    :styles => { :mini => '32x32>', :normal => '128x128>' },
    :default_style => :mini,
    :url => '/spree/taxons/:id/:style/:basename.:extension',
    :path => ':rails_root/public/spree/taxons/:id/:style/:basename.:extension',
    :default_url => '/assets/default_taxon.png'

  include ::Spree::ProductFilters  # for detailed defs of filters

  # indicate which filters should be used for a taxon
  # this method should be customized to your own site
  def applicable_filters
    fs = []
    # fs << ProductFilters.taxons_below(self)
    ## unless it's a root taxon? left open for demo purposes

    fs << Spree::ProductFilters.price_filter if Spree::ProductFilters.respond_to?(:price_filter)
    fs << Spree::ProductFilters.brand_filter if Spree::ProductFilters.respond_to?(:brand_filter)
    fs
  end

  # Creates permalink based on .to_url method provided by stringx gem
  def set_permalink
    if parent_id.nil?
      self.permalink = name.to_url if self.permalink.blank?
    else
      parent_taxon = Spree::Taxon.find(parent_id)
      self.permalink = [parent_taxon.permalink, (self.permalink.blank? ? name.to_url : self.permalink.split('/').last)].join('/')
    end
  end

  def active_products
    scope = self.products.active
    scope = scope.on_hand unless Spree::Config[:show_zero_stock_products]
    scope
  end

  private
    # obsolete, kept for backwards compat
    def escape(str)
      str.blank? ? '' : str.to_url
    end
end
