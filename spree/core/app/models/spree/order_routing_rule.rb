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

    # acts_as_list only assigns bottom positions in before_create — too late
    # for the presence validation below, so API creates without an explicit
    # position would 422. Default to the end of the channel's list instead.
    before_validation :set_position_to_end, on: :create, if: -> { position.blank? && channel.present? }

    validates :type, :channel, presence: true
    # One instance of each rule kind per channel — a duplicate signal would
    # either be a no-op or fight itself in the reducer walk.
    validates :type, uniqueness: { scope: [:channel_id, *spree_base_uniqueness_scope] }
    validates :position, presence: true, numericality: { only_integer: true }
    validate :channel_belongs_to_store

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position) }
    scope :for_channel, ->(channel) { where(channel_id: channel.id) }

    acts_as_list scope: :channel_id

    self.whitelisted_ransackable_attributes = %w[type position active store_id channel_id]

    validate :type_must_be_registered

    # @return [String] localized display name for the rule kind, used by admin pickers
    def self.human_name
      Spree.t("order_routing_rule_types.#{api_type}.name", default: api_type.titleize)
    end

    # @return [String] localized description for the rule kind
    def self.human_description
      Spree.t("order_routing_rule_types.#{api_type}.description", default: '')
    end

    # Feeds the `description` field of `subclasses_with_preference_schema`
    # (the `/types` discovery payload), which only reads `.description`.
    def self.description
      human_description
    end

    def human_name = self.class.human_name
    def human_description = self.class.human_description

    # Subclasses override. Returns an Array<LocationRanking> — one per location,
    # with rank=nil to abstain.
    #
    # @param order     [Spree::Order]
    # @param locations [Array<Spree::StockLocation>]
    # @return [Array<LocationRanking>]
    def rank(_order, _locations)
      raise NotImplementedError, "#{self.class} must implement #rank(order, locations)"
    end

    # Routes Spree::PreferenceSchema's subclass discovery
    # (`subclasses_with_preference_schema`, `find_by_api_type`) to the
    # order-routing rule registry.
    module ClassMethods
      private

      def registered_subclasses
        Spree.order_routing.rules
      end
    end
    extend ClassMethods

    private

    def set_position_to_end
      self.position = bottom_position_in_list + 1
    end

    # The +type+ presence validation already covers blank; here we only reject
    # a present-but-unregistered STI type so arbitrary class names can't be
    # persisted via the +type+ column.
    def type_must_be_registered
      return if type.blank?
      return if Spree.order_routing.rules.any? { |rule| rule.to_s == type }

      errors.add(:type, Spree.t(:invalid_order_routing_rule, scope: [:errors, :messages], default: 'is not a registered order routing rule'))
    end

    def channel_belongs_to_store
      return if channel.nil? || store_id.nil?
      return if channel.store_id == store_id

      errors.add(:channel, Spree.t('errors.messages.channel_store_mismatch'))
    end
  end
end
