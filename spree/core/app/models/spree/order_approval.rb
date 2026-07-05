module Spree
  class OrderApproval < Spree.base_class
    has_prefix_id :appr

    STATUSES = %w[pending approved rejected].freeze

    attribute :metadata, default: -> { {} }

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :approvals
    belongs_to :approver, polymorphic: true, optional: true

    validates :order, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }

    scope :approved, -> { where(status: 'approved') }
    scope :pending,  -> { where(status: 'pending') }
    scope :rejected, -> { where(status: 'rejected') }
  end
end
