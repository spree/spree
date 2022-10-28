# TODO: let friendly id take care of sanitizing the url
require 'stringex'

module Spree
  class Taxon < Spree::Base
    include Metadata
    if defined?(Spree::Webhooks)
      include Spree::Webhooks::HasWebhooks
    end

    extend FriendlyId
    friendly_id :permalink, slug_column: :permalink, use: :history
    before_validation :set_permalink, on: :create, if: :name

    acts_as_nested_set dependent: :destroy

    belongs_to :taxonomy, class_name: 'Spree::Taxonomy', inverse_of: :taxons
    has_many :classifications, -> { order(:position) }, dependent: :delete_all, inverse_of: :taxon
    has_many :products, through: :classifications

    has_many :menu_items, as: :linked_resource
    has_many :cms_sections, as: :linked_resource

    has_many :prototype_taxons, class_name: 'Spree::PrototypeTaxon', dependent: :destroy
    has_many :prototypes, through: :prototype_taxons, class_name: 'Spree::Prototype'

    has_many :promotion_rule_taxons, class_name: 'Spree::PromotionRuleTaxon', dependent: :destroy
    has_many :promotion_rules, through: :promotion_rule_taxons, class_name: 'Spree::PromotionRule'

    validates :name, presence: true, uniqueness: { scope: [:parent_id, :taxonomy_id], allow_blank: true, case_sensitive: false }
    validates :taxonomy, presence: true
    validates :permalink, uniqueness: { case_sensitive: false, scope: [:parent_id, :taxonomy_id] }
    validates :hide_from_nav, inclusion: { in: [true, false] }
    validates_associated :icon
    validate :check_for_root, on: :create
    validate :parent_belongs_to_same_taxonomy
    with_options length: { maximum: 255 }, allow_blank: true do
      validates :meta_keywords
      validates :meta_description
      validates :meta_title
    end

    before_validation :copy_taxonomy_from_parent
    after_save :touch_ancestors_and_taxonomy
    after_update :sync_taxonomy_name
    after_touch :touch_ancestors_and_taxonomy

    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::TaxonImage'

    scope :for_store, ->(store) { joins(:taxonomy).where(spree_taxonomies: { store_id: store.id }) }

    self.whitelisted_ransackable_associations = %w[taxonomy]
    self.whitelisted_ransackable_attributes = %w[name permalink]

    scope :for_stores, ->(stores) { joins(:taxonomy).where(spree_taxonomies: { store_id: stores.ids }) }

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

    # Return meta_title if set otherwise generates from taxon name
    def seo_title
      meta_title.blank? ? name : meta_title
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
      ancestor_chain = ancestors.inject('') do |name, ancestor|
        name += "#{ancestor.name} -> "
      end
      ancestor_chain + name.to_s
    end

    def cached_self_and_descendants_ids
      Rails.cache.fetch("#{cache_key_with_version}/descendant-ids") do
        self_and_descendants.ids
      end
    end

    # awesome_nested_set sorts by :lft and :rgt. This call re-inserts the child
    # node so that its resulting position matches the observable 0-indexed position.
    # ** Note ** no :position column needed - a_n_s doesn't handle the reordering if
    #  you bring your own :order_column.
    #
    #  See #3390 for background.
    def child_index=(idx)
      move_to_child_with_index(parent, idx.to_i) unless new_record?
    end

    private

    def sync_taxonomy_name
      if saved_change_to_name? && root?
        return if taxonomy.name.to_s == name.to_s

        taxonomy.update(name: name)
      end
    end

    def touch_ancestors_and_taxonomy
      # Touches all ancestors at once to avoid recursive taxonomy touch, and reduce queries.
      ancestors.update_all(updated_at: Time.current)
      # Have taxonomy touch happen in #touch_ancestors_and_taxonomy rather than association option in order for imports to override.
      taxonomy.try!(:touch)
    end

    def check_for_root
      if taxonomy.try(:root).present? && parent_id.nil?
        errors.add(:root_conflict, 'this taxonomy already has a root taxon')
      end
    end

    def parent_belongs_to_same_taxonomy
      if parent.present? && parent.taxonomy_id != taxonomy_id
        errors.add(:parent, 'must belong to the same taxonomy')
      end
    end

    def copy_taxonomy_from_parent
      self.taxonomy = parent.taxonomy if parent.present? && taxonomy.blank?
    end
  end
end
