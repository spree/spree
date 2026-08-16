# frozen_string_literal: true

module Spree
  # One targeting clause on a Spree::CommissionRate: this rate applies to this
  # product, this category, or this seller.
  #
  # Not STI, unlike the promotion and price rules: a commission rule carries no
  # behavior of its own and no preferences — it names a record, and matching is
  # set membership. The dimension it constrains is its `subject_type`, so
  # adding one (a channel, a market) needs no new class.
  #
  # A rule with no subject is a global one, which reads the same as a rate
  # holding no rules at all; both match every sale.
  class CommissionRule < Spree.base_class
    has_prefix_id :comrl

    SUBJECT_TYPES = %w[Spree::Product Spree::Category Spree::Vendor].freeze

    belongs_to :commission_rate, class_name: 'Spree::CommissionRate', inverse_of: :commission_rules
    belongs_to :subject, polymorphic: true, optional: true

    validates :subject_type, inclusion: { in: SUBJECT_TYPES }, allow_blank: true
    validates :subject_id, presence: true, if: -> { subject_type.present? }
    validates :subject_type, presence: true, if: -> { subject_id.present? }
    validates :subject_id, uniqueness: { scope: [:commission_rate_id, :subject_type] }, allow_nil: true

    # @return [Boolean]
    def global?
      subject_type.blank? || subject_id.blank?
    end
  end
end
