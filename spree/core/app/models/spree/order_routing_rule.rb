module Spree
  # STI base for order routing rules. Subclasses live in
  # app/models/spree/order_routing/rules/ and implement #rank(order, locations).
  #
  # Plugins extend the engine by defining a new subclass:
  #
  #   class AcmeFresh::OrderRouting::RefrigeratedRule < Spree::OrderRoutingRule
  #     preference :max_temp_c, :integer, default: 4
  #
  #     def rank(order, locations)
  #       # ... return Array<LocationRanking>
  #     end
  #   end
  #
  # See docs/plans/6.0-order-routing.md.
  class OrderRoutingRule < Spree.base_class
    self.table_name = 'spree_order_routing_rules'

    # `rank` is integer (lower = better) when the rule has an opinion,
    # nil to abstain (the reducer skips abstaining rankings).
    LocationRanking = Struct.new(:location, :rank, keyword_init: true)

    has_prefix_id :orule

    include Spree::SingleStoreResource

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :channel, class_name: 'Spree::Channel'

    attribute :active, :boolean, default: true

    validates :type, :channel, presence: true
    validates :position, presence: true, numericality: { only_integer: true }
    validate :channel_belongs_to_store

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position) }
    scope :for_channel, ->(channel) { where(channel_id: channel.id) }

    acts_as_list scope: :channel_id

    self.whitelisted_ransackable_attributes = %w[type position active store_id channel_id]

    validate :type_must_be_registered

    # Registered (available) rule kinds. Backed by
    # +Rails.application.config.spree.order_routing_rules+; register or
    # unregister via that array. STI still handles runtime dispatch.
    #
    # @return [Array<Class>]
    def self.registered
      Array(Spree.order_routing_rules)
    end

    # @param klass_name [String, Class, nil]
    # @return [Boolean] whether the class is a registered rule kind
    def self.registered?(klass_name)
      registered.any? { |klass| klass.to_s == klass_name.to_s }
    end

    # Subclasses override. Returns an Array<LocationRanking> — one per location,
    # with rank=nil to abstain.
    #
    # @param order     [Spree::Order]
    # @param locations [Array<Spree::StockLocation>]
    # @return [Array<LocationRanking>]
    def rank(_order, _locations)
      raise NotImplementedError, "#{self.class} must implement #rank(order, locations)"
    end

    private

    # The +type+ presence validation already covers blank; here we only reject
    # a present-but-unregistered STI type so arbitrary class names can't be
    # persisted via the +type+ column.
    def type_must_be_registered
      return if type.blank?
      return if self.class.registered?(type)

      errors.add(:type, Spree.t(:invalid_order_routing_rule, scope: [:errors, :messages], default: 'is not a registered order routing rule'))
    end

    def channel_belongs_to_store
      return if channel.nil? || store_id.nil?
      return if channel.store_id == store_id

      errors.add(:channel, Spree.t('errors.messages.channel_store_mismatch'))
    end
  end
end
