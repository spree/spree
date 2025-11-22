require 'stringex'

module Spree
  class Taxon < Spree.base_class
    RULES_MATCH_POLICIES = %w[all any].freeze
    SORT_ORDERS = %w[
      manual
      best-selling
      name-a-z
      name-z-a
      price-high-to-low
      price-low-to-high
      newest-first
      oldest-first
    ]

    include Spree::TranslatableResource
    include Spree::TranslatableResourceSlug
    include Spree::Metafields
    include Spree::Metadata
    include Spree::MemoizedData
    include Spree::Linkable
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    MEMOIZED_METHODS = %w[cached_self_and_descendants_ids].freeze

    #
    # Magic methods
    #
    extend FriendlyId
    friendly_id :permalink, slug_column: :permalink, use: :history
    acts_as_nested_set dependent: :destroy

    #
    # Associations
    #
    belongs_to :taxonomy, class_name: 'Spree::Taxonomy', inverse_of: :taxons
    has_one :store, through: :taxonomy
    has_many :classifications, -> { order(:position) }, dependent: :destroy_async, inverse_of: :taxon
    has_many :products, through: :classifications
    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::TaxonImage' # TODO: remove this as this is deprecated

    has_many :prototype_taxons, class_name: 'Spree::PrototypeTaxon', dependent: :destroy
    has_many :prototypes, through: :prototype_taxons, class_name: 'Spree::Prototype'

    has_many :promotion_rule_taxons, class_name: 'Spree::PromotionRuleTaxon', dependent: :destroy
    has_many :promotion_rules, through: :promotion_rule_taxons, class_name: 'Spree::PromotionRule'

    #
    # Attachments
    #
    has_one_attached :image, service: Spree.public_storage_service_name
    has_one_attached :square_image, service: Spree.public_storage_service_name

    #
    # Validations
    #
    validates :name, presence: true, uniqueness: { scope: [:parent_id, :taxonomy_id], case_sensitive: false }
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
    validates :image, :square_image, content_type: Rails.application.config.active_storage.web_image_content_types

    #
    # Callbacks
    #
    before_validation :set_permalink, on: :create, if: :name
    before_validation :copy_taxonomy_from_parent
    before_save :set_pretty_name
    before_save :set_permalink
    after_save :touch_ancestors_and_taxonomy
    after_update :sync_taxonomy_name
    after_touch :touch_ancestors_and_taxonomy
    after_commit :regenerate_pretty_name_and_permalink, on: :update, if: :should_regenerate_pretty_name_and_permalink?
    after_move :regenerate_pretty_name_and_permalink
    after_move :regenerate_translations_pretty_name_and_permalink

    after_commit :touch_featured_sections, on: [:update]
    after_touch :touch_featured_sections
    after_destroy :remove_featured_sections, if: -> { featured? }

    #
    # Scopes
    #
    scope :for_store, ->(store) { joins(:taxonomy).where(spree_taxonomies: { store_id: store.id }) }
    scope :for_stores, ->(stores) { joins(:taxonomy).where(spree_taxonomies: { store_id: stores.ids }) }
    scope :for_taxonomy, lambda { |taxonomy_name|
      if Spree.use_translations?
        joins(:taxonomy).
          join_translation_table(Taxonomy).
          where(
            Taxonomy.arel_table_alias[:name].lower.matches(taxonomy_name.downcase.strip)
          )
      else
        joins(:taxonomy).where(Spree::Taxonomy.arel_table[:name].lower.matches(taxonomy_name.downcase.strip))
      end
    }

    #
    # Search
    #
    if defined?(PgSearch)
      include PgSearch::Model
      pg_search_scope :search_by_name, against: :name, using: { tsearch: { any_word: true, prefix: true } }
    else
      def self.search_by_name(query)
        i18n { name.lower.matches("%#{query.downcase}%") }
      end
    end

    scope :with_matching_name, ->(name_to_match) do
      value = name_to_match.to_s.strip.downcase

      if Spree.use_translations?
        i18n { name.lower.eq(value) }
      else
        where(arel_table[:name].lower.eq(value))
      end
    end

    #
    #  Ransack
    #
    self.whitelisted_ransackable_associations = %w[taxonomy]
    self.whitelisted_ransackable_attributes = %w[name permalink automatic]

    #
    # Translations
    #
    TRANSLATABLE_FIELDS = %i[name pretty_name description permalink].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    #
    # Action Text
    #
    translates :description, backend: :action_text

    # Automatic taxons
    validates :rules_match_policy, inclusion: { in: RULES_MATCH_POLICIES }, presence: true
    validates :sort_order, inclusion: { in: SORT_ORDERS }, presence: true

    has_many :taxon_rules, class_name: 'Spree::TaxonRule', dependent: :destroy
    accepts_nested_attributes_for :taxon_rules, allow_destroy: true, reject_if: proc { |attributes| attributes['value'].blank? }
    alias rules taxon_rules

    scope :manual, -> { where.not(automatic: true) }
    scope :automatic, -> { where(automatic: true) }

    after_commit :regenerate_taxon_products, on: [:update], if: -> { automatic? && saved_change_to_rules_match_policy? }
    attribute :marked_for_regenerate_taxon_products, :boolean, default: true

    def manual?
      !automatic?
    end

    def manual_sort_order?
      sort_order == 'manual'
    end

    def page_builder_image
      square_image.presence || image
    end

    def active_products_with_descendants
      @active_products_with_descendants ||= store.products.
                                            joins(:classifications).
                                            active.
                                            where(
                                              Spree::Classification.table_name => {
                                                taxon_id: descendants.ids + [id]
                                              }
                                            )
    end

    def products_matching_rules(opts = {})
      return Spree::Product.none if manual? || rules.empty?

      storefront = opts[:storefront] || false
      currency = opts[:currency] || store.default_currency

      all_products = store.products.not_archived

      products_matcher_cache_key = [
        'products_matching_rules',
        cache_key_with_version,
        storefront,
        currency,
        all_products.cache_key_with_version
      ]

      all_products = all_products.active(currency: currency) if storefront

      any_rules_match_policy = rules_match_policy == 'any'
      products = any_rules_match_policy ? Spree::Product.none : all_products

      rules.each do |rule|
        if any_rules_match_policy
          product_ids = rule.apply(all_products).ids
          # it's safer to use this approach with ids as it will not break if the rule is not a simple where clause
          # and we will avoid `ArgumentError (Relation passed to #or must be structurally compatible. Incompatible values: [:group, :order, :joins, :readonly])` error
          products = products.or(all_products.where(id: product_ids)) if product_ids.any?
        else
          products = rule.apply(products)
        end
      end

      products
    end

    # we need to create a new taxon product (classification) record for each product that matches the rules
    # so we can later use them for product filtering and so on
    # if we want to fire the service once during object lifecycle - pass only_once: true
    def regenerate_taxon_products(only_once: false)
      if marked_for_regenerate_taxon_products?
        Spree::Taxons::RegenerateProducts.call(taxon: self)
        self.marked_for_regenerate_taxon_products = false if !frozen? && only_once
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
        Spree::Taxon::Translation.where(spree_taxon_id: translated_model.cached_self_and_descendants_ids).each(&:update_pretty_name_and_permalink)
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
        [parent_permalink_with_fallback, (permalink.blank? ? name_with_fallback.to_url : permalink.split('/').last.to_url)].join('/')
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

    # indicate which filters should be used for a taxon
    # this method should be customized to your own site
    def applicable_filters
      Spree::Deprecation.warn('applicable_filters is deprecated and will be removed in Spree 6.0')
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

    def active_products
      products.active
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

    def page_builder_url
      return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:nested_taxons_path)

      Spree::Core::Engine.routes.url_helpers.nested_taxons_path(self)
    end

    def featured?
      featured_sections.any?
    end

    def featured_sections
      @featured_sections ||= Spree::PageSections::FeaturedTaxon.published.by_taxon_id(id)
    end

    private

    def should_regenerate_pretty_name_and_permalink?
      saved_changes.key?(:name) || saved_changes.key?(:permalink)
    end

    def sync_taxonomy_name
      if saved_changes.key?(:name) && root?
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

    def regenerate_translations_pretty_name_and_permalink
      translations.each(&:regenerate_pretty_name_and_permalink)
    end

    def touch_featured_sections
      Spree::Taxons::TouchFeaturedSections.call(taxon_ids: [id])
    end

    def remove_featured_sections
      featured_sections.destroy_all
    end
  end
end
