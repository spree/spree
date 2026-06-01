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
    has_many :product_publications, class_name: 'Spree::ProductPublication', dependent: :destroy
    has_many :products, through: :product_publications, class_name: 'Spree::Product'

    attribute :active, :boolean, default: true

    normalizes :code, with: ->(value) { value.to_s.parameterize.presence }

    before_validation :backfill_code_from_name, if: -> { code.blank? && name.present? }

    validates :name, :store, presence: true
    validates :code, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id] }

    after_create :ensure_default_order_routing_rules

    scope :active, -> { where(active: true) }

    self.whitelisted_ransackable_attributes = %w[name code active store_id]

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
      records_to_upsert = product_ids.map do |product_id|
        {
          channel_id:     id,
          store_id:       store_id,
          product_id:     product_id,
          published_at:   published_at,
          unpublished_at: unpublished_at,
          created_at:     now,
          updated_at:     now
        }
      end

      opts = { update_only: %i[published_at unpublished_at], on_duplicate: :update }
      # MySQL infers the conflict target from the table's unique constraints
      # and rejects an explicit +unique_by+; PostgreSQL/SQLite require it.
      opts[:unique_by] = %i[channel_id product_id store_id] unless ActiveRecord::Base.connection.adapter_name == 'Mysql2'

      Spree::ProductPublication.upsert_all(records_to_upsert, **opts)
      touch

      records_to_upsert.size
    end

    # Unpublishes the given products from this channel.
    # @param product_ids [Array<Integer>, Integer] the IDs of the products to unpublish
    # @return [Integer] the number of ProductPublications destroyed
    def remove_products(product_ids)
      product_ids = Array(product_ids).map(&:to_s).uniq
      return 0 if product_ids.empty?

      count = product_publications.where(product_id: product_ids).destroy_all.size
      touch if count.positive?
      count
    end

    private

    def backfill_code_from_name
      self.code = name
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
