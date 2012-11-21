module Spree
  class Taxon < ActiveRecord::Base
    acts_as_nested_set :dependent => :destroy

    belongs_to :taxonomy
    has_and_belongs_to_many :products, :join_table => 'spree_products_taxons'

    before_create :set_permalink

    attr_accessible :name, :parent_id, :position, :icon, :description, :permalink, :taxonomy_id

    validates :name, :presence => true

    has_attached_file :icon,
      :styles => { :mini => '32x32>', :normal => '128x128>' },
      :default_style => :mini,
      :url => '/spree/taxons/:id/:style/:basename.:extension',
      :path => ':rails_root/public/spree/taxons/:id/:style/:basename.:extension',
      :default_url => '/assets/default_taxon.png'

    include Spree::Core::S3Support
    supports_s3 :icon

    include ::Spree::ProductFilters  # for detailed defs of filters

    # indicate which filters should be used for a taxon
    # this method should be customized to your own site
    def applicable_filters
      fs = []
      # fs << ProductFilters.taxons_below(self)
      ## unless it's a root taxon? left open for demo purposes

      fs << ProductFilters.price_filter if ProductFilters.respond_to?(:price_filter)
      fs << ProductFilters.brand_filter if ProductFilters.respond_to?(:brand_filter)
      fs
    end

    # Creates permalink based on Stringex's .to_url method
    def set_permalink
      if parent_id.nil?
        self.permalink = name.to_url if permalink.blank?
      else
        parent_taxon = Taxon.find(parent_id)
        self.permalink = [parent_taxon.permalink, (permalink.blank? ? name.to_url : permalink.split('/').last)].join('/')
      end
    end

    def active_products
      scope = products.active
      scope = scope.on_hand unless Spree::Config[:show_zero_stock_products]
      scope
    end

    def pretty_name
      ancestor_chain = self.ancestors.inject("") do |name, ancestor|
        name += "#{ancestor.name} -> "
      end
      ancestor_chain + "#{name}"
    end

    def to_js_tree(max_depth, current_depth)
      rel = ""
      state = ""
      children_js = ""

      if current_depth < max_depth
        children_js = ", 'children' : [#{self.children.map{|t| t.to_js_tree(max_depth, current_depth+1)}.join(',')}]"
      end
      
      state = self.children.empty? ? "" : "closed"

      if current_depth == 0
        rel = ", 'rel' : 'root'"
        state = "open"
      end

      <<-END

          { "attr" :
          { "id" : "#{self.id}" #{rel}},
          "data" : "#{self.name.gsub('"','\"')}",
          "state" : "#{state}"
          #{children_js}
          }

      END
    end

  end
end
