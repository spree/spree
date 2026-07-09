# frozen_string_literal: true

require 'stringex'

module Spree
  class Collection < Spree.base_class
    include Spree::SingleStoreResource

    has_prefix_id :coll

    RULES_MATCH_POLICIES = %w[all any].freeze
    # Same values/format as Spree::Taxon::SORT_ORDERS — required by the search sort
    # pipeline (FiltersAggregator#to_api_sort splits on a space; apply_sort maps to 'price'/etc.).
    SORT_ORDERS = Spree::Taxon::SORT_ORDERS

    include Spree::TranslatableResource
    include Spree::TranslatableResourceSlug
    include Spree::Metafields
    include Spree::Metadata

    #
    # Slug / permalink — FriendlyId with history (mirrors Spree::Taxon; flat, no hierarchy).
    # `use: :history` keeps old permalinks resolving via the shared friendly_id_slugs table
    # after a rename. Declared before `translates` (as in Taxon). Within-store uniqueness is
    # still enforced by the validation + DB index below — a collision errors (as in Taxon),
    # it does not auto-suffix.
    #
    extend FriendlyId
    friendly_id :permalink, slug_column: :permalink, use: :history

    TRANSLATABLE_FIELDS = %i[name description permalink].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    #
    # Action Text
    #
    # Interim: description via ActionText (mirrors Spree::Taxon). 6.0-rich-text-descriptions.md
    # migrates both Category and Collection off ActionText later.
    translates :description, backend: :action_text

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'

    has_many :product_collections, class_name: 'Spree::ProductCollection', dependent: :destroy_async, inverse_of: :collection
    has_many :products, through: :product_collections

    has_many :collection_rules, class_name: 'Spree::CollectionRule', dependent: :destroy, inverse_of: :collection
    accepts_nested_attributes_for :collection_rules, allow_destroy: true, reject_if: proc { |attributes|
      attributes['value'].blank?
    }
    alias rules collection_rules

    #
    # Attachments
    #
    has_one_attached :image, service: Spree.public_storage_service_name
    has_one_attached :square_image, service: Spree.public_storage_service_name

    #
    # Positioning (flat, store-scoped)
    #
    acts_as_list scope: :store_id

    #
    # Validations
    #
    validates :name, presence: true
    validates :permalink, uniqueness: { scope: :store_id, case_sensitive: false, allow_blank: true }
    validates :rules_match_policy, inclusion: { in: RULES_MATCH_POLICIES }, presence: true
    validates :sort_order, inclusion: { in: SORT_ORDERS }, presence: true
    validates :hide_from_nav, inclusion: { in: [true, false] }

    before_validation :set_permalink, if: :name

    #
    # Scopes
    #
    scope :manual, -> { where.not(automatic: true) }
    scope :automatic, -> { where(automatic: true) }

    #
    # Automatic (rule-based) membership
    #
    after_commit :regenerate_products, on: [:update], if: -> { automatic? && saved_change_to_rules_match_policy? }
    attribute :marked_for_regenerate_products, :boolean, default: true

    def manual?
      !automatic?
    end

    def manual_sort_order?
      sort_order == 'manual'
    end

    def slug
      permalink
    end

    def slug=(value)
      self.permalink = value
    end

    # Rebuild the materialized ProductCollection membership from the rules.
    # Pass only_once: true to fire at most once per object lifecycle.
    #
    # @param only_once [Boolean]
    # @return [void]
    def regenerate_products(only_once: false)
      return unless marked_for_regenerate_products?

      Spree::Collections::RegenerateProducts.call(collection: self)
      self.marked_for_regenerate_products = false if !frozen? && only_once
    end

    # Products matching the automatic rules (mirrors Spree::Taxon#products_matching_rules).
    #
    # @return [ActiveRecord::Relation]
    def products_matching_rules(opts = {})
      return Spree::Product.none if manual? || rules.empty?

      currency = opts[:currency] || store.default_currency
      storefront = opts[:storefront] || false

      all_products = store.products.not_archived
      all_products = all_products.active(currency: currency) if storefront

      any_rules_match_policy = rules_match_policy == 'any'
      products = any_rules_match_policy ? Spree::Product.none : all_products

      rules.each do |rule|
        if any_rules_match_policy
          product_ids = rule.apply(all_products).ids
          products = products.or(all_products.where(id: product_ids)) if product_ids.any?
        else
          products = rule.apply(products)
        end
      end

      products
    end

    # Slug generation, flat (no parent hierarchy). Mirrors Spree::Taxon's dual set_permalink:
    # with translations off, the model writes the base permalink column directly (which
    # column_fallback routes the default locale to, bypassing the Translation before_save);
    # with translations on, each Translation generates its own. An existing permalink is
    # sticky — renaming the collection does not rewrite it (set permalink explicitly to change).
    def set_permalink
      if Spree.use_translations?
        translations.each(&:set_permalink)
      else
        self.permalink = generate_slug
      end
    end

    def generate_slug
      permalink.blank? ? name.to_url : permalink.to_url
    end

    # Per-locale slug accessors + generation on the Mobility translation.
    self::Translation.class_eval do
      before_save :set_permalink

      def slug
        permalink
      end

      def slug=(value)
        self.permalink = value
      end

      def set_permalink
        self.permalink = generate_slug
      end

      def name_with_fallback
        name.blank? ? translated_model[:name] : name
      end

      private

      def generate_slug
        permalink.blank? ? name_with_fallback.to_url : permalink.to_url
      end
    end
  end
end
