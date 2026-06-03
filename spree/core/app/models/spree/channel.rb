module Spree
  # Lightweight distribution surface within a Store: online storefront, POS,
  # marketplace integration, wholesale portal. Channels carry order
  # attribution and the routing-strategy override.
  class Channel < Spree.base_class
    DEFAULT_CODE = 'online'.freeze

    has_prefix_id :ch

    include Spree::SingleStoreResource
    include Spree::Metafields
    include Spree::Metadata

    # Empty -> falls back to the Store-level preference.
    preference :order_routing_strategy, :string, default: nil

    belongs_to :store, class_name: 'Spree::Store'

    has_many :orders, class_name: 'Spree::Order', inverse_of: :channel, dependent: :nullify
    has_many :order_routing_rules, class_name: 'Spree::OrderRoutingRule', dependent: :destroy
    has_many :publications, class_name: 'Spree::ProductPublication', dependent: :destroy
    has_many :products, through: :publications, class_name: 'Spree::Product'

    attribute :active, :boolean, default: true

    # Force UTF-8 before parameterize. HTTP headers reach Rails as ASCII-8BIT
    # and +String#parameterize+ raises +ArgumentError+ on non-UTF-8 input
    # ("Cannot transliterate strings with ASCII-8BIT encoding"). Channel codes
    # are slugs ([a-z0-9-]) so the bytes are already valid UTF-8.
    normalizes :code, with: ->(value) { value.to_s.dup.force_encoding(Encoding::UTF_8).parameterize.presence }

    before_validation :backfill_code_from_name, if: -> { code.blank? && name.present? }
    before_validation :promote_first_channel_to_default

    validates :name, :store, presence: true
    validates :code, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id] }

    # Demote any prior default in the same transaction so the partial unique
    # index ("only one default per store") never sees two TRUE rows. Runs
    # before save so MySQL — which can't enforce a partial unique index — also
    # arrives at a single default without relying on DB constraints.
    before_save :demote_other_defaults, if: -> { default? && will_save_change_to_default? }
    before_destroy :ensure_not_default
    after_create :ensure_default_order_routing_rules

    scope :active, -> { where(active: true) }
    scope :default, -> { where(default: true) }

    self.whitelisted_ransackable_attributes = %w[name code active default store_id]

    # Publishes the given products on this channel by creating/upserting ProductPublications.
    # Optionally sets the publication window; if not given, the products will be published immediately
    # with no end date.
    # @param product_ids [Array<Integer>, Integer] the IDs of the products to publish on this channel
    # @param published_at [Time, nil] when the publications go live; nil means immediately
    # @param unpublished_at [Time, nil] when the publications come down; nil means never
    # @return [Integer] the number of ProductPublications created or updated
    def add_products(product_ids, published_at: nil, unpublished_at: nil)
      product_ids = Array(product_ids).map(&:to_s).uniq
      return 0 if product_ids.empty?

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

      records_to_upsert = product_ids.map { |product_id| base.merge(product_id: product_id) }

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
      opts[:unique_by] = %i[product_id channel_id] unless mysql_adapter?

      Spree::ProductPublication.upsert_all(records_to_upsert, **opts)

      products = Spree::Product.where(id: product_ids)
      products.touch_all
      products.each(&:enqueue_search_index)
      touch

      records_to_upsert.size
    end

    # Unpublishes the given products from this channel.
    # @param product_ids [Array<Integer>, Integer] the IDs of the products to unpublish
    # @return [Integer] the number of ProductPublications destroyed
    def remove_products(product_ids)
      product_ids = Array(product_ids).map(&:to_s).uniq
      return 0 if product_ids.empty?

      count = publications.where(product_id: product_ids).destroy_all.size

      products = Spree::Product.where(id: product_ids)
      products.touch_all
      products.each(&:enqueue_search_index)

      touch if count.positive?
      count
    end

    # The default channel of a store is the storefront's fallback when no
    # +X-Spree-Channel+ is given, so removing it would orphan all storefront
    # traffic. Promote another channel to default first.
    # @return [Boolean]
    def can_be_deleted?
      !default?
    end

    private

    def ensure_not_default
      return if can_be_deleted?
      # Allow store cascade — destroying the store removes its channels too.
      return if destroyed_by_association.present?

      errors.add(:base, Spree.t('errors.messages.cannot_delete_default_channel'))
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
