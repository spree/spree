module Spree
  # Lightweight distribution surface within a Store: online storefront, POS,
  # marketplace integration, wholesale portal. Channels carry order
  # attribution and the routing-strategy override.
  class Channel < Spree.base_class
    DEFAULT_CODE = 'online'.freeze

    has_prefix_id :ch

    include Spree::SingleStoreResource
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::OrderRouting::HasStrategyPreference
    include Spree::Channel::Gating

    # Empty -> falls back to the Store-level preference.
    preference :order_routing_strategy, :string, default: nil,
                                                 parse_on_set: ->(value) { Spree::ApiTyped.class_name_for(Spree.order_routing.strategies, value) }
    exposes_preferences :order_routing_strategy


    has_many :orders, class_name: 'Spree::Order', inverse_of: :channel, dependent: :nullify
    has_many :order_routing_rules, class_name: 'Spree::OrderRoutingRule', dependent: :destroy
    has_many :publications, class_name: 'Spree::ProductPublication', dependent: :destroy
    has_many :products, through: :publications, class_name: 'Spree::Product'
    has_many :category_publications, class_name: 'Spree::CategoryPublication', dependent: :destroy, inverse_of: :channel
    has_many :categories, through: :category_publications, class_name: 'Spree::Category'
    has_many :collection_publications, class_name: 'Spree::CollectionPublication', dependent: :destroy, inverse_of: :channel
    has_many :collections, through: :collection_publications, class_name: 'Spree::Collection'
    # When set, only the default catalog's products are visible on this
    # channel; unset means all publications.
    belongs_to :default_catalog, class_name: 'Spree::Catalog', optional: true
    has_many :api_keys, class_name: 'Spree::ApiKey', dependent: :nullify
    # Optional fulfillment-origin allowlist: no rows means every store
    # location serves this channel (docs/plans/6.0-channel-delivery.md).
    has_many :channel_stock_locations, class_name: 'Spree::ChannelStockLocation',
             dependent: :destroy, inverse_of: :channel
    has_many :stock_locations, through: :channel_stock_locations, class_name: 'Spree::StockLocation',
             dependent: :destroy

    attribute :active, :boolean, default: true

    # HTTP headers arrive as ASCII-8BIT; +parameterize+ raises on those.
    normalizes :code, with: ->(value) { value.to_s.dup.force_encoding(Encoding::UTF_8).parameterize.presence }

    before_validation :backfill_code_from_name, if: -> { code.blank? && name.present? }
    before_validation :promote_first_channel_to_default

    validates :name, presence: true
    validates :code, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id] }

    # Demote any prior default in the same transaction so the partial unique
    # index ("only one default per store") never sees two TRUE rows. Runs
    # before save so MySQL — which can't enforce a partial unique index — also
    # arrives at a single default without relying on DB constraints.
    before_save :demote_other_defaults, if: -> { default? && will_save_change_to_default? }
    before_destroy :ensure_not_default
    # prepend: the +dependent: :nullify+ on +api_keys+ registers its own
    # before_destroy at association-declaration time; without prepend it would
    # clear every binding before this guard could see them.
    before_destroy :ensure_no_active_bound_api_keys, prepend: true
    after_create :ensure_default_order_routing_rules

    scope :active, -> { where(active: true) }
    scope :default, -> { where(default: true) }

    self.whitelisted_ransackable_attributes = %w[name code active default store_id]
    search_by :name

    # Publishes records of one kind (products, categories or collections) on
    # every channel in the current scope
    # (`store.channels.where(id: ids).publish_records(Spree::Category, category_ids)`),
    # refreshing each record once rather than once per channel. Re-publishing
    # keeps an existing window unless a new one is given.
    # @param model_class [Class<Spree::ChannelPublishable>]
    # @param record_ids [Array<Integer>, Integer]
    # @param published_at [Time, nil] when the publications go live; nil means immediately
    # @param unpublished_at [Time, nil] when the publications come down; nil means never
    # @param publish_events [Boolean] whether each new publication sends `<record>.published`
    # @return [Integer] the number of publications created or updated
    def self.publish_records(model_class, record_ids, published_at: nil, unpublished_at: nil, publish_events: true)
      record_ids = Array(record_ids).map(&:to_s).uniq
      channels = all.to_a
      return 0 if record_ids.empty? || channels.empty?

      count = channels.sum do |channel|
        channel.send(:upsert_publications, model_class, record_ids, published_at, unpublished_at, publish_events)
      end
      model_class.refresh_after_publishing(record_ids)
      channels.each(&:touch)
      count
    end

    # Unpublishes records of one kind from every channel in the current scope.
    # @param model_class [Class<Spree::ChannelPublishable>]
    # @param record_ids [Array<Integer>, Integer]
    # @return [Integer] the number of publications destroyed
    def self.unpublish_records(model_class, record_ids)
      record_ids = Array(record_ids).map(&:to_s).uniq
      channels = all.to_a
      return 0 if record_ids.empty? || channels.empty?

      reflection = model_class.reflect_on_association(model_class.publications_association)
      removed = reflection.klass.includes(reflection.inverse_of.name, :channel).
                where(channel_id: channels.map(&:id), reflection.foreign_key => record_ids).destroy_all
      model_class.refresh_after_publishing(record_ids)
      emptied_channel_ids = removed.map(&:channel_id).uniq
      channels.select { |channel| emptied_channel_ids.include?(channel.id) }.each(&:touch)
      removed.size
    end

    # Publishes the given products on every channel in the current scope.
    # @param product_ids [Array<Integer>, Integer]
    # @return [Integer] the number of ProductPublications created or updated
    def self.add_products(product_ids)
      publish_records(Spree::Product, product_ids)
    end

    # Unpublishes the given products from every channel in the current scope.
    # @param product_ids [Array<Integer>, Integer]
    # @return [Integer] the number of ProductPublications destroyed
    def self.remove_products(product_ids)
      unpublish_records(Spree::Product, product_ids)
    end

    # @param product_ids [Array<String>]
    # @return [void]
    def self.refresh_products(product_ids)
      Spree::Product.refresh_after_publishing(product_ids)
    end

    # Publishes records of one kind on this channel, with an optional window.
    # @see .publish_records
    def publish_records(model_class, record_ids, published_at: nil, unpublished_at: nil, publish_events: true)
      self.class.where(id: id).publish_records(model_class, record_ids, published_at: published_at, unpublished_at: unpublished_at,
                                                                        publish_events: publish_events)
    end

    # Unpublishes records of one kind from this channel.
    # @see .unpublish_records
    def unpublish_records(model_class, record_ids)
      self.class.where(id: id).unpublish_records(model_class, record_ids)
    end

    # Publishes the given products on this channel. Optionally sets the
    # publication window; if not given, the products will be published
    # immediately with no end date.
    # @param product_ids [Array<Integer>, Integer] the IDs of the products to publish on this channel
    # @param published_at [Time, nil] when the publications go live; nil means immediately
    # @param unpublished_at [Time, nil] when the publications come down; nil means never
    # @return [Integer] the number of ProductPublications created or updated
    def add_products(product_ids, published_at: nil, unpublished_at: nil)
      publish_records(Spree::Product, product_ids, published_at: published_at, unpublished_at: unpublished_at)
    end

    # Unpublishes the given products from this channel.
    # @param product_ids [Array<Integer>, Integer] the IDs of the products to unpublish
    # @return [Integer] the number of ProductPublications destroyed
    def remove_products(product_ids)
      unpublish_records(Spree::Product, product_ids)
    end

    # @return [Boolean]
    def can_be_deleted?
      !default? && !api_keys.active.exists?
    end

    # Whether packages originating from this stock location may serve this
    # channel's carts. No linked locations means every store location.
    #
    # @param stock_location [Spree::StockLocation, nil]
    # @return [Boolean]
    def serves_location?(stock_location)
      return false if stock_location.nil?
      return true if served_stock_location_ids.empty?

      served_stock_location_ids.include?(stock_location.id)
    end

    # @return [Array<Integer>] ids of the locations this channel is limited to
    def served_stock_location_ids
      @served_stock_location_ids ||= channel_stock_locations.map(&:stock_location_id)
    end

    # The locations allowed to fulfill this channel's traffic.
    #
    # @return [ActiveRecord::Relation<Spree::StockLocation>]
    def served_stock_locations
      return store.stock_locations if served_stock_location_ids.empty?

      store.stock_locations.where(id: served_stock_location_ids)
    end

    private

    # The bulk upsert skips the publication callbacks, so the events for the
    # newly created rows are sent here.
    def upsert_publications(model_class, record_ids, published_at, unpublished_at, publish_events)
      reflection = model_class.reflect_on_association(model_class.publications_association)
      publish_events &&= model_class.channel_publication_events
      existing_ids = if publish_events
                       reflection.klass.where(channel_id: id, reflection.foreign_key => record_ids).pluck(reflection.foreign_key).map(&:to_s)
                     else
                       []
                     end
      count = upsert_publication_rows(reflection.klass, reflection.foreign_key.to_sym, record_ids, published_at, unpublished_at)
      return count unless publish_events

      model_class.where(store_id: store_id, id: record_ids - existing_ids).find_each do |record|
        record.publish_event("#{record.event_prefix}.published", nil, { channel_id: prefixed_id })
      end
      count
    end

    def upsert_publication_rows(publication_class, foreign_key, record_ids, published_at, unpublished_at)
      now = Time.current
      # Only include window columns in the upsert payload when the caller
      # explicitly passed a value. Leaving them out keeps existing
      # publication schedules intact on re-publish — otherwise +on_duplicate:
      # :update+ + +update_only+ would rewrite scheduled +published_at+ /
      # +unpublished_at+ to NULL whenever the bulk action re-runs without
      # dates.
      base = { channel_id: id, created_at: now, updated_at: now }
      base[:published_at] = published_at unless published_at.nil?
      base[:unpublished_at] = unpublished_at unless unpublished_at.nil?

      records_to_upsert = record_ids.map { |record_id| base.merge(foreign_key => record_id) }

      # Only update the window columns the caller passed. When neither was
      # passed, treat re-publish as a no-op (+on_duplicate: :skip+ → MySQL
      # +INSERT IGNORE+, PG/SQLite +ON CONFLICT DO NOTHING+).
      update_columns = []
      update_columns << :published_at unless published_at.nil?
      update_columns << :unpublished_at unless unpublished_at.nil?
      opts = if update_columns.empty?
               { on_duplicate: :skip }
             else
               { record_timestamps: false, update_only: update_columns, on_duplicate: :update }
             end
      # MySQL infers the conflict target from the table's unique constraints
      # and rejects an explicit +unique_by+; PostgreSQL/SQLite require it.
      opts[:unique_by] = [foreign_key, :channel_id] unless mysql_adapter?

      publication_class.upsert_all(records_to_upsert, **opts)
      records_to_upsert.size
    end

    def ensure_not_default
      return unless default?
      return if destroyed_by_association.present?

      errors.add(:base, :cannot_delete_default_channel, message: I18n.t('spree.errors.messages.cannot_delete_default_channel'))
      throw :abort
    end

    # Fail closed: deleting a channel must not silently convert its bound
    # publishable keys into unbound (store-wide) credentials via the
    # +dependent: :nullify+ above. Active keys block deletion — revoke or
    # rebind them first; revoked keys are historical and nullify freely.
    # Store-cascade deletes skip the guard (the keys die with the store).
    def ensure_no_active_bound_api_keys
      return unless api_keys.active.exists?
      return if destroyed_by_association.present?

      errors.add(:base, :cannot_delete_channel_with_active_api_keys, message: I18n.t('spree.errors.messages.cannot_delete_channel_with_active_api_keys'))
      throw :abort
    end

    def backfill_code_from_name
      self.code = name
    end

    # First channel on a store becomes the default. Lets the
    # +Stores::Channels#ensure_default_channel+ seed path and the legacy
    # admin "create channel" form both produce a sensible default without
    # the caller having to know.
    def promote_first_channel_to_default
      return if default
      return unless new_record? && store_id.present?

      self.default = true unless Spree::Channel.where(store_id: store_id).exists?
    end

    def demote_other_defaults
      Spree::Channel.where(store_id: store_id, default: true).where.not(id: id).update_all(default: false)
    end

    # Default ordering: preferred location wins, then minimize splits, then
    # fall back to StockLocation.default. See docs/plans/6.0-order-routing.md.
    def ensure_default_order_routing_rules
      return if order_routing_rules.any?

      Spree::OrderRouting::Rules::PreferredLocation.create!(store: store, channel: self, position: 1)
      Spree::OrderRouting::Rules::MinimizeSplits.create!(store: store , channel: self, position: 2)
      Spree::OrderRouting::Rules::DefaultLocation.create!(store: store, channel: self, position: 3)
    end
  end
end
