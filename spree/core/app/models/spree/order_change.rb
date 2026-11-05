module Spree
  # A set of proposed changes to a placed order, previewed and then applied
  # in one transaction (docs/plans/6.1-order-change-substrate.md).
  #
  # Admin order edits, return and exchange receipts and replacement shipments
  # all reach the order through one of these, so every post-placement change
  # has the same lifecycle and leaves the same record. The model holds
  # associations and reads only: moving a set between statuses is a workflow
  # (`Spree::OrderChanges::Confirm.call(order_change:)`), and the money a set
  # moves is derived by previewing, never stored here.
  class OrderChange < Spree.base_class
    has_prefix_id :ordchg

    include Spree::ActedBy
    include Spree::HasStatus
    include Spree::Metadata

    publishes_lifecycle_events
    publishes_events :requested, :confirmed, :canceled

    OPEN_STATUSES = %w[pending requested].freeze

    # pending → requested → confirmed | canceled | declined
    has_status :pending, :requested, :confirmed, :canceled, :declined, default: :pending

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :order_changes
    # Staff only — a customer-initiated change leaves this nil.
    acted_by :requested_by

    # The business operation that opened the set; none for an admin edit.
    belongs_to :return, class_name: 'Spree::Return', optional: true, inverse_of: :order_changes
    belongs_to :exchange, class_name: 'Spree::Exchange', optional: true, inverse_of: :order_changes
    belongs_to :claim, class_name: 'Spree::Claim', optional: true, inverse_of: :order_changes

    has_many :actions, -> { order(:position, :id) }, class_name: 'Spree::OrderChangeAction',
                                                     dependent: :destroy, inverse_of: :order_change

    self.whitelisted_ransackable_attributes = %w[status created_at confirmed_at]

    # Applier classes for kinds an extension registered, by kind. Core kinds
    # are applied by Spree::OrderChanges::ApplyActions itself.
    class_attribute :action_appliers, default: {}, instance_writer: false

    # Adds an action kind and the class that applies it at confirm (and,
    # rolled back, at preview). The applier is called as
    # `applier.new.call(order_change:, action:)` inside the confirm
    # transaction; it writes through ordinary models and raises to abort.
    #
    #   Spree::OrderChange.register_action_kind('gift_wrap', 'MyApp::ApplyGiftWrap')
    #
    # @param kind [String, Symbol]
    # @param applier [String, Class] held by name, so a code reload is picked up
    def self.register_action_kind(kind, applier)
      kind = kind.to_s
      raise ArgumentError, "#{kind} is applied by Spree itself and cannot be registered" if Spree::OrderChangeAction::CORE_KINDS.include?(kind)

      Spree::OrderChangeAction.kinds += [kind] unless Spree::OrderChangeAction.kinds.include?(kind)
      self.action_appliers = action_appliers.merge(kind => applier.to_s)
    end

    # @return [Boolean] whether actions can still be added or the set applied
    def open?
      OPEN_STATUSES.include?(status)
    end

    # Takes the order's row lock, then re-reads this set's status under its
    # own, so a confirm or cancel that waited for another sees what that one
    # left. Only the status is re-read: actions already loaded are kept.
    # Call inside a transaction.
    #
    # @return [String] the current status
    def lock_for_transition!
      order.lock!
      self.status = self.class.lock.where(id: id).pick(:status)
    end

    # A receipt or a replacement shipment changes no amount on the order, and
    # re-summing a placed order can call out to a tax provider, so a set of
    # only those is applied without one.
    #
    # @return [Boolean]
    def moves_money?
      actions.any? { |action| Spree::OrderChangeAction::STOCK_KINDS.exclude?(action.kind) }
    end

    # The return, exchange or claim this set belongs to, if any.
    #
    # @return [Spree::Return, Spree::Exchange, Spree::Claim, nil]
    def post_sale_record
      self.return || exchange || claim
    end

    def event_serializer_class
      'Spree::Api::V3::OrderChangeEventSerializer'.safe_constantize
    end
  end
end
