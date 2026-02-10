module Spree
  class CouponCode < Spree.base_class
    has_prefix_id :coupon

    include Spree::Security::CouponCodes if defined?(Spree::Security::CouponCodes)

    enum :state, %i(unused used)

    acts_as_paranoid

    scope :used_with_code, ->(code) { used.where(code: code.downcase) }
    scope :with_order, ->(order_id) { where(order_id: order_id) }
    scope :in_promotions, ->(promotion_ids) { where(promotion_id: promotion_ids) }
    scope :not_in_promotions, ->(promotion_ids) { where.not(promotion_id: promotion_ids) }

    belongs_to :promotion, class_name: 'Spree::Promotion', touch: true
    belongs_to :order, class_name: 'Spree::Order'

    validates :code, presence: true, uniqueness: { scope: spree_base_uniqueness_scope, conditions: -> { where(deleted_at: nil) } }
    validates :state, :promotion, presence: true

    self.whitelisted_ransackable_attributes = %w[state code]

    def self.used?(code)
      used_with_code(code).any?
    end

    def apply_order!(order)
      update(order: order, state: 'used')
    end

    def remove_from_order
      update(order: nil, state: 'unused')
    end

    def display_code
      code.upcase
    end
  end
end
