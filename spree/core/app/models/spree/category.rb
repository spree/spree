# frozen_string_literal: true

require 'stringex'

module Spree
  # The hierarchical product category (formerly Spree::Taxon), on spree_categories,
  # owned directly via store_id — a parentless category is a genuine top-level node.
  # Spree::Taxon is retained as a deprecation alias for one release. Rule-based
  # (automatic) membership now lives on Spree::Collection.
  class Category < Spree.base_class
    include Spree::SingleStoreResource

    has_prefix_id :ctg

    include Spree::TranslatableResource
    include Spree::TranslatableResourceSlug
    include Spree::Metafields
    include Spree::Metadata
    include Spree::MemoizedData

    MEMOIZED_METHODS = %w[cached_self_and_descendants_ids].freeze

    #
    # Magic methods
    #
    extend FriendlyId
    friendly_id :permalink, slug_column: :permalink, use: :history
    acts_as_nested_set dependent: :destroy, counter_cache: :children_count

    #
    # Associations
    #
    belongs_to :taxonomy, class_name: 'Spree::Taxonomy', inverse_of: :taxons
    belongs_to :store, class_name: 'Spree::Store', optional: true
    has_many :product_categories, -> { order(:position) }, class_name: 'Spree::ProductCategory', dependent: :destroy_async, inverse_of: :category
    has_many :products, through: :product_categories

    # @deprecated Use #product_categories; removed in 6.1.
    def classifications
      product_categories
    end

    # spree_prototype_taxons keeps its taxon_id column (the prototype join is
    # renamed by 6.0-product-types), so pin the foreign key there.
    has_many :prototype_taxons, class_name: 'Spree::PrototypeTaxon', foreign_key: :taxon_id, dependent: :destroy
    has_many :prototypes, through: :prototype_taxons, class_name: 'Spree::Prototype'

    has_many :promotion_rule_categories, class_name: 'Spree::PromotionRuleCategory', dependent: :destroy
    has_many :promotion_rules, through: :promotion_rule_categories, class_name: 'Spree::PromotionRule'

    #
    # Attachments
    #
    has_one_attached :image, service: Spree.public_storage_service_name
    has_one_attached :square_image, service: Spree.public_storage_service_name

    #
    # Validations
    #
    validates :name, presence: true
    validates :taxonomy, presence: true, if: :requires_taxonomy?
    validates :store, presence: true
    # Taxonomy-backed categories are unique within their taxonomy; taxonomy-less
    # categories (store-owned) are unique within their store, so two stores can
    # each have a top-level "Shoes".
    validates :name, uniqueness: { scope: %i[parent_id taxonomy_id], case_sensitive: false }, if: :requires_taxonomy?
    validates :permalink, uniqueness: { scope: %i[parent_id taxonomy_id], case_sensitive: false }, if: :requires_taxonomy?
    validates :name, uniqueness: { scope: %i[parent_id store_id], case_sensitive: false }, unless: :requires_taxonomy?
    validates :permalink, uniqueness: { scope: %i[parent_id store_id], case_sensitive: false }, unless: :requires_taxonomy?
    validates :hide_from_nav, inclusion: { in: [true, false] }
    validate :check_for_root, on: :create
    validate :parent_belongs_to_same_taxonomy
    with_options length: { maximum: 255 }, allow_blank: true do
      validates :meta_keywords
      validates :meta_description
      validates :meta_title
    end
    validates :image, :square_image, content_type: Rails.application.config.active_storage.web_image_content_types

    #
    # Callbacks
    #
    before_validation :set_permalink, if: :name
    before_validation :copy_taxonomy_from_parent
    before_save :set_pretty_name
    after_save :touch_ancestors_and_taxonomy
    after_update :sync_taxonomy_name
    after_touch :touch_ancestors_and_taxonomy
    after_commit :regenerate_pretty_name_and_permalink, on: :update, if: :should_regenerate_pretty_name_and_permalink?
    after_move :regenerate_pretty_name_and_permalink
    after_move :regenerate_translations_pretty_name_and_permalink
    # Moving a subtree shifts its products under a new ancestor chain (and away
    # from the old one), so recompute both branches' inclusive products_count.
    # Capture the old parent before the move; recompute both chains after.
    before_move :capture_parent_before_move
    after_move :recalculate_products_count_after_move
    # A move changes the subtree's ancestor set (indexed category_ids) and its
    # per-grouping positions, so refresh the moved subtree's products in search.
    after_move :reindex_products_after_move
    # Destroying a category drops its subtree's products from every ancestor's
    # inclusive count. Recompute the ancestors here (while the doomed subtree's
    # rows still exist) excluding that subtree, since the ProductCategory destroy
    # callbacks can't help: product_categories are removed via destroy_async, so
    # they outlive this callback and their category may already be gone.
    before_destroy :recalculate_ancestors_before_destroy, prepend: true

    #
    # Scopes
    #
    # Prefer the direct store_id column; fall back to the taxonomy join for rows
    # not yet backfilled (store_id IS NULL) so legacy behaviour is preserved.
    scope :for_store, ->(store) { for_stores([store]) }
    scope :for_stores, lambda { |stores|
      store_ids = Array(stores).map(&:id)
      taxonomy_ids = Spree::Taxonomy.where(store_id: store_ids).select(:id)
      where(store_id: store_ids).or(where(store_id: nil, taxonomy_id: taxonomy_ids))
    }
    scope :for_taxonomy, lambda { |taxonomy_name|
      Spree::Deprecation.warn('Spree::Category.for_taxonomy is deprecated and will be removed in Spree 6. Please use for_store instead.')

      if Spree.use_translations?
        joins(:taxonomy)
          .join_translation_table(Taxonomy)
          .where(
            Taxonomy.arel_table_alias[:name].lower.matches(taxonomy_name.downcase.strip)
          )
      else
        joins(:taxonomy).where(Spree::Taxonomy.arel_table[:name].lower.matches(taxonomy_name.downcase.strip))
      end
    }

    #
    # Search
    #
    def self.search_by_name(query)
      i18n { name.lower.matches("%#{query.downcase}%") }
    end

    scope :with_matching_name, lambda { |name_to_match|
      value = name_to_match.to_s.strip.downcase

      if Spree.use_translations?
        i18n { name.lower.eq(value) }
      else
        where(arel_table[:name].lower.eq(value))
      end
    }

    #
    #  Ransack
    #
    self.whitelisted_ransackable_associations = %w[taxonomy parent]
    self.whitelisted_ransackable_attributes = %w[name permalink automatic depth is_root children_count
                                                 products_count pretty_name hide_from_nav parent_id]

    #
    # Translations
    #
    TRANSLATABLE_FIELDS = %i[name pretty_name description permalink].freeze
    RICH_TEXT_TRANSLATABLE_FIELDS = %i[description].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

    #
    # Action Text
    #
    translates :description, backend: :action_text

    # Categories are manual only in 6.0 — rule-based (automatic) membership lives on
    # Spree::Collection. The automatic/rules_match_policy/sort_order columns and the
    # spree_taxon_rules table are retained for the Phase 4 data migration and dropped
    # in 6.1. The manual scope stays as a guard against any stray automatic row on the
    # category surfaces (a no-op once the migration clears them).
    scope :manual, -> { where.not(automatic: true) }

    def manual?
      !automatic?
    end

    # The owning store. Prefers the direct +store_id+; falls back to the
    # taxonomy's store for legacy rows not yet backfilled.
    def store
      super || taxonomy&.store
    end

    # Categories are owned directly via +store_id+ and never require a taxonomy.
    # (Legacy taxonomy-backed rows still carry their taxonomy until it is dropped
    # in 6.1; they simply aren't validated as requiring one.)
    def requires_taxonomy?
      false
    end

    def active_products_with_descendants
      @active_products_with_descendants ||= store.products
                                                 .joins(:product_categories)
                                                 .active
                                                 .where(
                                                   Spree::ProductCategory.table_name => {
                                                     category_id: descendants.ids + [id]
                                                   }
                                                 )
    end

    # Recomputes the stored, descendant-inclusive +products_count+ for the given
    # categories AND all of their ancestors — the nodes whose inclusive count can
    # shift when a product_category changes. Counts unique products classified
    # under each node or its descendants (a product reachable through several
    # nodes is counted once per ancestor). Call after any product_category change.
    #
    # @param category_ids [Array<Integer>] categories whose branch counts changed
    def self.recalculate_products_count(category_ids)
      changed = unscoped.where(id: Array(category_ids).compact.uniq)

      # The affected nodes are each changed category plus its ancestors.
      affected = changed.flat_map { |category| category.self_and_ancestors.to_a }.uniq(&:id)

      affected.each do |category|
        count = Spree::ProductCategory.where(category_id: category.self_and_descendants.select(:id))
                                     .distinct.count(:product_id)
        category.update_column(:products_count, count) if category.products_count != count
      end
    end

    def slug
      permalink
    end

    def slug=(value)
      self.permalink = value
    end

    self::Translation.class_eval do
      before_save :set_permalink
      before_save :set_pretty_name
      after_save :regenerate_pretty_name_and_permalink, if: :should_regenerate_pretty_name_and_permalink?

      def slug
        permalink
      end

      def slug=(value)
        self.permalink = value
      end

      def set_permalink
        self.permalink = generate_slug
      end

      def set_pretty_name
        self.pretty_name = generate_pretty_name
      end

      def name_with_fallback
        name.blank? ? translated_model[:name] : name
      end

      def pretty_name_with_fallback
        pretty_name.blank? ? translated_model[:pretty_name] : pretty_name
      end

      def regenerate_pretty_name_and_permalink
        Spree::Category::Translation.where(spree_category_id: translated_model.cached_self_and_descendants_ids).each(&:update_pretty_name_and_permalink)
      end

      def update_pretty_name_and_permalink
        update_columns(pretty_name: generate_pretty_name, permalink: generate_slug, updated_at: Time.current)
      end

      private

      def generate_slug
        if parent.present?
          generate_permalink_including_parent
        elsif permalink.blank?
          name_with_fallback.to_url
        else
          permalink.to_url
        end
      end

      def generate_pretty_name
        if parent.present?
          generate_pretty_name_including_parent
        elsif pretty_name.blank?
          name_with_fallback
        else
          pretty_name
        end
      end

      def generate_permalink_including_parent
        [parent_permalink_with_fallback,
         (permalink.blank? ? name_with_fallback.to_url : permalink.split('/').last.to_url)].join('/')
      end

      def generate_pretty_name_including_parent
        [parent_pretty_name_with_fallback, (name.blank? ? name_with_fallback : name)].compact.join(' -> ')
      end

      def parent
        translated_model.parent
      end

      def parent_permalink_with_fallback
        localized_parent = parent.translations.find_by(locale: locale)
        localized_parent.present? ? localized_parent.permalink : parent[:permalink]
      end

      def parent_pretty_name_with_fallback
        localized_parent = parent.translations.find_by(locale: locale)
        localized_parent.present? ? localized_parent.pretty_name : parent[:pretty_name]
      end

      def should_regenerate_pretty_name_and_permalink?
        saved_changes.key?(:name) || saved_changes.key?(:permalink)
      end
    end

    # Return meta_title if set otherwise generates from category name
    def seo_title
      meta_title.blank? ? name : meta_title
    end

    def set_pretty_name
      self.pretty_name = generate_pretty_name
    end

    def generate_pretty_name
      [parent&.pretty_name, name].compact.join(' -> ')
    end

    def generate_slug
      if parent.present?
        [parent.permalink, (permalink.blank? ? name.to_url : permalink.split('/').last.to_url)].join('/')
      elsif permalink.blank?
        name.to_url
      else
        permalink.to_url
      end
    end

    def set_permalink
      if Spree.use_translations?
        translations.each(&:set_permalink)
      else
        self.permalink = generate_slug
      end
    end

    def regenerate_pretty_name_and_permalink
      Mobility.with_locale(nil) do
        update_columns(pretty_name: generate_pretty_name, permalink: generate_slug, updated_at: Time.current)
      end

      children.reload.each(&:regenerate_pretty_name_and_permalink_as_child)
    end

    def regenerate_pretty_name_and_permalink_as_child
      Mobility.with_locale(nil) do
        update_columns(pretty_name: generate_pretty_name, permalink: generate_slug, updated_at: Time.current)
      end

      children.reload.each(&:regenerate_pretty_name_and_permalink_as_child)
    end

    def cached_self_and_descendants_ids
      @cached_self_and_descendants_ids ||= Rails.cache.fetch("#{cache_key_with_version}/descendant-ids") do
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

    def should_regenerate_pretty_name_and_permalink?
      saved_changes.key?(:name) || saved_changes.key?(:permalink)
    end

    # Refresh the moved subtree's products in the search index (their ancestor
    # category_ids + per-grouping positions changed). Guarded so DB-provider stores
    # (no indexing) skip the query entirely; enqueue_search_index self-guards too.
    def reindex_products_after_move
      return unless Spree.search_provider.constantize.indexing_required?

      Spree::Product.joins(:product_categories).
        where(Spree::ProductCategory.table_name => { category_id: self_and_descendants.select(:id) }).
        distinct.
        find_each(&:enqueue_search_index)
    rescue NameError
      nil
    end

    def sync_taxonomy_name
      return unless taxonomy.present?
      return unless saved_changes.key?(:name) && root?
      return if taxonomy.name.to_s == name.to_s

      taxonomy.update(name: name)
    end

    def touch_ancestors_and_taxonomy
      # Touches all ancestors at once to avoid recursive taxonomy touch, and reduce queries.
      ancestors.update_all(updated_at: Time.current)
      # Have taxonomy touch happen in #touch_ancestors_and_taxonomy rather than association option in order for imports to override.
      taxonomy.touch if taxonomy.present?
    end

    def capture_parent_before_move
      @parent_id_before_move = parent_id_in_database
    end

    # Recompute the inclusive products_count for the moved node's new ancestor
    # chain and the previous parent's chain too (whose subtree just lost this
    # node's products).
    def recalculate_products_count_after_move
      affected = [id, @parent_id_before_move].compact
      @parent_id_before_move = nil
      self.class.recalculate_products_count(affected)
    end

    # Recomputes each ancestor's inclusive products_count as if this subtree were
    # already gone (its product_categories are destroyed asynchronously, so they're
    # still present here). Excludes self_and_descendants from the count.
    def recalculate_ancestors_before_destroy
      doomed_ids = self_and_descendants.ids
      ancestors.each do |ancestor|
        remaining = Spree::ProductCategory.
                    where(category_id: ancestor.self_and_descendants.where.not(id: doomed_ids).select(:id)).
                    distinct.count(:product_id)
        ancestor.update_column(:products_count, remaining) if ancestor.products_count != remaining
      end
    end

    def check_for_root
      return unless taxonomy.try(:root).present? && parent_id.nil?

      errors.add(:root_conflict, 'this taxonomy already has a root category')
    end

    def parent_belongs_to_same_taxonomy
      return unless parent.present? && parent.taxonomy_id != taxonomy_id

      errors.add(:parent, 'must belong to the same taxonomy')
    end

    def copy_taxonomy_from_parent
      self.taxonomy = parent.taxonomy if parent.present? && taxonomy.blank?
    end

    def set_store
      Spree::Deprecation.warn('Spree::Category#set_store is deprecated and will be removed in Spree 6.0. ensure_store instead.')
      ensure_store
    end

    # Every category is store-owned. Resolve the store from the taxonomy, then the
    # parent, finally the current store — so the direct column is always
    # populated for new records. Guards on the raw +store_id+ column rather than
    # +#store+, whose reader masks an unset column with the taxonomy fallback.
    def ensure_store
      return if store_id.present?

      self.store = taxonomy&.store || parent&.store || Spree::Store.current
    end

    def regenerate_translations_pretty_name_and_permalink
      translations.each(&:regenerate_pretty_name_and_permalink)
    end
  end
end
