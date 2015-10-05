module Spree
  module UserMethods
    extend ActiveSupport::Concern

    include Spree::UserApiAuthentication
    include Spree::UserPaymentSource
    include Spree::UserReporting
    include Spree::RansackableAttributes

    included do
      has_many :role_users, class_name: 'Spree::RoleUser', foreign_key: :user_id
      has_many :spree_roles, through: :role_users, class_name: 'Spree::Role', source: :role

      has_many :promotion_rule_users, class_name: 'Spree::PromotionRuleUser'
      has_many :promotion_rules, through: :promotion_rule_users, class_name: 'Spree::PromotionRule'

      has_many :orders, foreign_key: :user_id, class_name: "Spree::Order"

      belongs_to :ship_address, class_name: 'Spree::Address'
      belongs_to :bill_address, class_name: 'Spree::Address'

      self.whitelisted_ransackable_associations = %w[bill_address ship_address]
      self.whitelisted_ransackable_attributes = %w[id email]
    end

    # has_spree_role? simply needs to return true or false whether a user has a role or not.
    def has_spree_role?(role_in_question)
      spree_roles.where(name: role_in_question.to_s).any?
    end

    def last_incomplete_spree_order
      orders.incomplete.
        includes(line_items: [variant: [:images, :option_values, :product]]).
        order('created_at DESC').
        first
    end

    def analytics_id
      id
    end
  end
end
