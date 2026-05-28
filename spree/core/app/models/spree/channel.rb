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

    validates :name, :store, presence: true
    validates :code, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id] }

    after_create :ensure_default_order_routing_rules

    scope :active, -> { where(active: true) }

    self.whitelisted_ransackable_attributes = %w[name code active store_id]

    private

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
