module Spree
  module UserMethods
    extend ActiveSupport::Concern

    include Spree::UserPaymentSource
    include Spree::UserReporting
    include Spree::RansackableAttributes

    included do
      # we need to have this callback before any dependent: :destroy associations
      # https://github.com/rails/rails/issues/3458
      before_destroy :check_completed_orders

      has_many :role_users, class_name: 'Spree::RoleUser', foreign_key: :user_id, dependent: :destroy
      has_many :spree_roles, through: :role_users, class_name: 'Spree::Role', source: :role

      has_many :promotion_rule_users, class_name: 'Spree::PromotionRuleUser', foreign_key: :user_id, dependent: :destroy
      has_many :promotion_rules, through: :promotion_rule_users, class_name: 'Spree::PromotionRule'

      has_many :orders, foreign_key: :user_id, class_name: 'Spree::Order'
      has_many :store_credits, foreign_key: :user_id, class_name: 'Spree::StoreCredit'

      belongs_to :ship_address, class_name: 'Spree::Address', optional: true
      belongs_to :bill_address, class_name: 'Spree::Address', optional: true

      self.whitelisted_ransackable_associations = %w[bill_address ship_address]
      self.whitelisted_ransackable_attributes = %w[id email]
    end

    # has_spree_role? simply needs to return true or false whether a user has a role or not.
    def has_spree_role?(role_in_question)
      spree_roles.any? { |role| role.name == role_in_question.to_s }
    end

    def last_incomplete_spree_order(store)
      orders.where(store: store).incomplete.
        includes(line_items: [variant: [:images, :option_values, :product]]).
        order('created_at DESC').
        first
    end

    def analytics_id
      id
    end

    def total_available_store_credit
      store_credits.reload.to_a.sum(&:amount_remaining)
    end

    private

    def check_completed_orders
      raise Spree::Core::DestroyWithOrdersError if orders.complete.present?
    end
  end
end
