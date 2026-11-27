module Spree
  # One step on an order's timeline: a payment settled, a fulfillment
  # shipped, a change confirmed, a staff comment
  # (docs/plans/6.1-order-timeline.md).
  #
  # Written by {Spree::OrderActivitySubscriber} from the events the order's
  # records publish, or by a staff member commenting, and never changed after.
  # `details` keeps what the entry shows and could not read later — amounts,
  # numbers, a card's last digits — and never a person's name or address.
  class OrderActivity < Spree.base_class
    has_prefix_id :ordact

    include Spree::ActedBy

    COMMENT = 'comment'.freeze

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :activities
    belongs_to :order_change, class_name: 'Spree::OrderChange', optional: true
    acted_by :actor

    validates :kind, :category, presence: true
    validates :body, presence: true, length: { maximum: 5_000 }, if: :comment?

    scope :comments, -> { where(kind: COMMENT) }

    self.whitelisted_ransackable_attributes = %w[kind category created_at]

    # @return [Boolean]
    def comment?
      kind == COMMENT
    end
  end
end
