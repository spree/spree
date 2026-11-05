# frozen_string_literal: true

require 'stringex'

module Spree
  class Collection < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::HasListPosition

    has_prefix_id :coll

    publishes_events :published, :unpublished

    RULES_MATCH_POLICIES = %w[all any].freeze
    # Space format (e.g. 'price asc') is required by the search sort pipeline:
    # FiltersAggregator#to_api_sort splits on a space, and apply_sort maps to 'price'/etc.
    SORT_ORDERS = [
      'manual',
      'best_selling',
      'price asc',
      'price desc',
      'available_on desc',
      'available_on asc',
      'name asc',
      'name desc'
    ].freeze

    include Spree::TranslatableResource
    include Spree::TranslatableResourceSlug
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::SanitizableRichText
    include Spree::HasLibraryMedia

    #
    # Slug / permalink — FriendlyId with history (mirrors Spree::Category; flat, no hierarchy).
    # `use: :history` keeps old permalinks resolving via the shared friendly_id_slugs table
    # after a rename. Declared before `translates` (as in Taxon). Within-store uniqueness is
    # still enforced by the validation + DB index below — a collision errors (as in Taxon),
    # it does not auto-suffix.
    #
    extend FriendlyId
    friendly_id :permalink, slug_column: :permalink, use: :history

    TRANSLATABLE_FIELDS = %i[name description permalink].freeze
    RICH_TEXT_TRANSLATABLE_FIELDS = %i[description].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

    #
    # Rich text
    #
    has_spree_rich_text :description

    self::Translation.class_eval do
      include Spree::SanitizableRichText

      sanitizes_rich_text :description
    end

    #
    # Associations
    #

    has_many :product_collections, class_name: 'Spree::ProductCollection', dependent: :destroy_async, inverse_of: :collection
    has_many :products, through: :product_collections

    has_many :publications, class_name: 'Spree::CollectionPublication', dependent: :destroy, inverse_of: :collection
    has_many :channels, through: :publications, class_name: 'Spree::Channel'

    has_many :promotion_rule_collections, class_name: 'Spree::PromotionRuleCollection', dependent: :delete_all
    has_many :exclusions, class_name: 'Spree::CollectionExclusion', dependent: :delete_all, inverse_of: :collection
    has_many :excluded_products, through: :exclusions, source: :product, class_name: 'Spree::Product'

    has_many :rules, class_name: 'Spree::CollectionRule', dependent: :destroy, inverse_of: :collection
    accepts_nested_attributes_for :rules, allow_destroy: true, reject_if: proc { |attributes|
      attributes['value'].blank?
    }

    #
    # Attachments
    #
    has_one_attached :image, service: Spree.public_storage_service_name
    has_one_attached :square_image, service: Spree.public_storage_service_name
    signed_id_attachments :image, :square_image
    # The slots double as media-library placements, so an upload here is
    # visible and reusable there (Spree::HasLibraryMedia).
    has_library_media :image, :square_image

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

    before_validation :set_permalink, if: :name
    after_save :apply_pending_publications, if: -> { @pending_publications }

    #
    # Scopes
    #
    scope :manual, -> { where.not(automatic: true) }
    scope :automatic, -> { where(automatic: true) }
    scope :with_rule_types, ->(rule_types) { where(id: Spree::CollectionRule.where(type: rule_types.map(&:to_s)).select(:collection_id)) }
    # Collections live on the channel now: a publication exists and its window is open.
    scope :published_on, lambda { |channel|
      where(id: Spree::CollectionPublication.published.where(channel_id: channel&.id).select(:collection_id))
    }

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[permalink automatic sort_order products_count]
    search_by :name

    #
    # Automatic (rule-based) membership
    #
    after_commit :regenerate_products, on: [:update], if: -> { saved_change_to_rules_match_policy? && rules.exists? }
    attribute :marked_for_regenerate_products, :boolean, default: true

    # `automatic` means "has rules": saving or removing a rule keeps the
    # column in step. Membership mixes rule-matched and hand-picked products
    # either way. Rules left on a collection that was manual before 6.1 stay
    # inert until a rule is saved on it.
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

    # Replaces the collection's publications with the given set: one hash per
    # channel (`channel_id`, optional `published_at` / `unpublished_at`).
    # Channels left out are unpublished. Applied after save, so a new
    # collection gets an id first. Channels of another store are ignored.
    #
    # @param publications_params [Array<Hash>, Array<Spree::CollectionPublication>]
    # @return [void]
    def publications=(publications_params)
      if publications_params.nil? || publications_params.first.is_a?(Spree::CollectionPublication)
        super
      else
        @publications_assigned = true
        @pending_publications = publications_params.map { |row| row.to_h.with_indifferent_access }
      end
    end

    # @return [Boolean] whether the save carries a publications set
    def publications_assigned?
      @publications_assigned == true
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

    # Names the source of memberships from before 6.1, which have none until
    # the upgrade step runs: on a collection that was automatic they came
    # from its rules. Runs before the automatic flag changes.
    #
    # @return [void]
    def claim_unknown_membership_sources!
      product_collections.where(source: nil).update_all(source: automatic? ? 'rule' : 'manual')
    end

    # Keeps `automatic` in step with the rules.
    #
    # @return [void]
    def sync_automatic!
      return if destroyed?

      has_rules = rules.exists?
      return if automatic? == has_rules

      claim_unknown_membership_sources!
      update_columns(automatic: has_rules)
    end

    # Regenerates in the background, for writes that shouldn't wait for it.
    #
    # @return [void]
    def enqueue_regenerate_products
      Spree::Collections::RegenerateProductsJob.perform_later(id) if automatic?
    end

    # Products matching the automatic rules (mirrors Spree::Category#products_matching_rules).
    # Pass `product_ids:` to evaluate only those products.
    #
    # @return [ActiveRecord::Relation]
    def products_matching_rules(opts = {})
      return Spree::Product.none if manual? || rules.empty?

      currency = opts[:currency] || store.default_currency
      storefront = opts[:storefront] || false

      all_products = store.products.not_archived
      all_products = all_products.where(id: opts[:product_ids]) if opts.key?(:product_ids)
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

    # Maps a wire `type` onto a registered rule class name. Accepts both the
    # `/collection_rules/types` shorthand (`tag`) and the STI class name,
    # matching how every other subclassed resource is written.
    #
    # Matching is string-only against the in-memory registry — nothing from the
    # wire is ever constantized. An unregistered value resolves to nil, which
    # leaves the record as the abstract base class so it fails CollectionRule's
    # type validation with a 422 (assigning it would make ActiveRecord raise
    # SubclassNotFound, a 500).
    #
    # @param type [String, nil] wire shorthand or STI class name
    # @return [String, nil] the registered class name, or nil when unregistered
    def self.resolve_rule_type(type)
      return nil if type.blank?

      Rails.application.config.spree.collection_rules.
        find { |klass| klass.api_type == type.to_s }&.to_s
    end

    # Syncs automatic rules from an array of attribute hashes by mutating the
    # in-memory `rules` association: hashes with an id update the matching rule
    # (accepting the prefixed `crule_` id), hashes without an id build a new
    # rule (the STI `type` selects the subclass), and any existing rule absent
    # from the payload is destroyed. Autosave persists the whole set in the
    # parent's save transaction. Mirrors Spree::OptionType#option_values= so the
    # Admin API can send the full desired rule set and have it round-trip.
    #
    # Falls back to the association writer when given CollectionRule records
    # (non-API callers / accepts_nested_attributes_for).
    #
    # @param rules_params [Array<Hash>] array of rule attribute hashes
    # @return [void]
    def rules=(rules_params)
      return super if rules_params.blank? || rules_params.first.is_a?(Spree::CollectionRule)

      existing_by_id = rules.to_a.index_by(&:id)
      retained_ids = []

      rules_params.each_with_index do |rule_data, index|
        data = rule_data.to_h.with_indifferent_access
        rule_id = data.delete(:id)
        preferences = data.delete(:preferences)
        if data.key?(:type) || rule_id.blank?
          # Refused with the accepted kinds named; letting the nil through
          # answered "type can't be blank" to a caller who had sent one.
          data[:type] = self.class.resolve_rule_type(data[:type]) ||
                        raise(unknown_row_type_error(Spree::CollectionRule, data[:type], "/rules/#{index}"))
        end

        existing = if rule_id.present?
                     existing_by_id[Spree::CollectionRule.decode_own_prefixed_id(rule_id) || rule_id] ||
                       raise(ActiveRecord::RecordNotFound.new("Couldn't find Spree::CollectionRule with param=#{rule_id}", 'Spree::CollectionRule'))
                   end

        # A new type is a new rule: the subclass decodes and validates its own
        # value, so the old record is replaced rather than retyped.
        record = if existing && (data[:type].nil? || data[:type] == existing.type)
                   existing.tap { |rule| rule.assign_attributes(data) }
                 else
                   rules.build(data)
                 end
        record.assign_preferences(preferences, pointer: "/rules/#{index}/preferences") unless preferences.nil?
        retained_ids << record.id if record.persisted?
      end

      existing_by_id.each_value do |existing|
        existing.mark_for_destruction unless retained_ids.include?(existing.id)
      end
    end

    # Slug generation, flat (no parent hierarchy). Mirrors Spree::Category's dual set_permalink:
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

    private

    def apply_pending_publications
      rows = @pending_publications
      @pending_publications = nil
      if rows.any? { |row| row[:channel_id].blank? }
        errors.add(:publications, :blank)
        raise ActiveRecord::RecordInvalid, self
      end

      channels_by_id = store.channels.where(id: rows.map { |row| decode_channel_id(row[:channel_id]) }).index_by(&:id)
      existing = publications.to_a.index_by(&:channel_id)
      kept = rows.filter_map do |row|
        channel = channels_by_id[decode_channel_id(row[:channel_id]).to_i]
        next unless channel

        publication = existing[channel.id] || publications.build(channel: channel)
        unless publication.update(row.slice(:published_at, :unpublished_at))
          publication.errors.each { |error| errors.add(:publications, error.full_message) }
          raise ActiveRecord::RecordInvalid, self
        end
        publication
      end

      (existing.values - kept).each(&:destroy!)
    end

    def decode_channel_id(value)
      Spree::Channel.decode_own_prefixed_id(value.to_s) || value
    end
  end
end
