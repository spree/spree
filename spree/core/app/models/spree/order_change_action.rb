module Spree
  # One proposed mutation inside a Spree::OrderChange: a typed `kind` plus
  # the concrete rows it touches, never a polymorphic subject
  # (docs/plans/decisions.md 2026-07-27).
  #
  #   add_item         variant, quantity
  #   update_item      line_item, quantity
  #   remove_item      line_item
  #   receive_item     variant, quantity — restocks at the return's or exchange's location
  #   add_fulfillment  line_item, variant, quantity — ships a replacement
  class OrderChangeAction < Spree.base_class
    has_prefix_id :ordchga

    include Spree::Metadata

    ITEM_KINDS = %w[add_item update_item remove_item].freeze
    # Kinds that move goods but not money: a set of only these leaves the
    # order total alone, so confirming it skips the re-sum.
    STOCK_KINDS = %w[receive_item add_fulfillment].freeze
    CORE_KINDS = (ITEM_KINDS + STOCK_KINDS).freeze

    # Configuration, not a frozen constant: Spree::OrderChange.register_action_kind
    # appends here alongside registering the applier.
    class_attribute :kinds, default: CORE_KINDS.dup

    belongs_to :order_change, class_name: 'Spree::OrderChange', inverse_of: :actions

    belongs_to :line_item, class_name: 'Spree::LineItem', optional: true
    belongs_to :variant, class_name: 'Spree::Variant', optional: true
    belongs_to :fulfillment, class_name: 'Spree::Fulfillment', optional: true
    belongs_to :delivery_method, class_name: 'Spree::DeliveryMethod', optional: true

    validates :kind, inclusion: { in: ->(record) { record.class.kinds } }
    validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :variant, presence: true, if: -> { kind.in?(%w[add_item receive_item add_fulfillment]) }
    validates :line_item, presence: true, if: -> { kind.in?(%w[update_item remove_item add_fulfillment]) }
    validates :quantity, presence: true, if: -> { kind.in?(%w[add_item update_item receive_item add_fulfillment]) }
    validate :line_item_belongs_to_order
    validate :stock_kind_has_post_sale_record

    private

    # A line item from another order would let one set edit someone else's.
    def line_item_belongs_to_order
      return if line_item.nil? || order_change.nil?
      return if line_item.order_id == order_change.order_id

      errors.add(:line_item, :invalid)
    end

    # Restocks and replacement shipments are what a return, exchange or claim
    # does once it has checked what came back and what is owed; on their own
    # they would move stock nobody accounted for.
    def stock_kind_has_post_sale_record
      return unless STOCK_KINDS.include?(kind)
      return if order_change&.post_sale_record

      errors.add(:kind, :requires_post_sale_record,
                 message: I18n.t('spree.order_change_requires_post_sale_record'))
    end
  end
end
