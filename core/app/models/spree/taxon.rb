# TODO let friendly id take care of sanitizing the url
require 'stringex'

module Spree
  class Taxon < Spree::Base
    extend FriendlyId
    friendly_id :permalink, slug_column: :permalink, use: :slugged
    before_create :set_permalink

    acts_as_nested_set dependent: :destroy

    belongs_to :taxonomy, class_name: 'Spree::Taxonomy', inverse_of: :taxons
    has_many :classifications, -> { order(:position) }, dependent: :delete_all, inverse_of: :taxon
    has_many :products, through: :classifications

    has_many :prototype_taxons, class_name: 'Spree::PrototypeTaxon'
    has_many :prototypes, through: :prototype_taxons, class_name: 'Spree::Prototype'

    has_many :promotion_rule_taxons, class_name: 'Spree::PromotionRuleTaxon'
    has_many :promotion_rules, through: :promotion_rule_taxons, class_name: 'Spree::PromotionRule'

    validates :name, presence: true
    with_options length: { maximum: 255 }, allow_blank: true do
      validates :meta_keywords
      validates :meta_description
      validates :meta_title
    end

    after_save :touch_ancestors_and_taxonomy
    after_touch :touch_ancestors_and_taxonomy

    has_attached_file :icon,
      styles: { mini: '32x32>', normal: '128x128>' },
      default_style: :mini,
      url: '/spree/taxons/:id/:style/:basename.:extension',
      path: ':rails_root/public/spree/taxons/:id/:style/:basename.:extension',
      default_url: '/assets/default_taxon.png'

    validates_attachment :icon,
      content_type: { content_type: ["image/jpg", "image/jpeg", "image/png", "image/gif"] }

    # indicate which filters should be used for a taxon
    # this method should be customized to your own site
    def applicable_filters
      fs = []
      # fs << ProductFilters.taxons_below(self)
      ## unless it's a root taxon? left open for demo purposes

      fs << Spree::Core::ProductFilters.price_filter if Spree::Core::ProductFilters.respond_to?(:price_filter)
      fs << Spree::Core::ProductFilters.brand_filter if Spree::Core::ProductFilters.respond_to?(:brand_filter)
      fs
    end

    # Return meta_title if set otherwise generates from root name and/or taxon name
    def seo_title
      unless meta_title.blank?
        meta_title
      else
        root? ? name : "#{root.name} - #{name}"
      end
    end

    # Creates permalink base for friendly_id
    def set_permalink
      if parent.present?
        self.permalink = [parent.permalink, (permalink.blank? ? name.to_url : permalink.split('/').last)].join('/')
      else
        self.permalink = name.to_url if permalink.blank?
      end
    end

    def active_products
      products.active
    end

    def pretty_name
      ancestor_chain = self.ancestors.inject("") do |name, ancestor|
        name += "#{ancestor.name} -> "
      end
      ancestor_chain + "#{name}"
    end

    # awesome_nested_set sorts by :lft and :rgt. This call re-inserts the child
    # node so that its resulting position matches the observable 0-indexed position.
    # ** Note ** no :position column needed - a_n_s doesn't handle the reordering if
    #  you bring your own :order_column.
    #
    #  See #3390 for background.
    def child_index=(idx)
      move_to_child_with_index(parent, idx.to_i) unless self.new_record?
    end

    private

    def touch_ancestors_and_taxonomy
      # Touches all ancestors at once to avoid recursive taxonomy touch, and reduce queries.
      ancestors.update_all(updated_at: Time.current)
      # Have taxonomy touch happen in #touch_ancestors_and_taxonomy rather than association option in order for imports to override.
      taxonomy.try!(:touch)
    end
  end
end
