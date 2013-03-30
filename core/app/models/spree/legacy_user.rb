# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
module Spree
  class LegacyUser < ActiveRecord::Base
    self.table_name = 'spree_users'
    attr_accessible :email, :password, :password_confirmation

    has_many :orders, foreign_key: :user_id
    belongs_to :ship_address, class_name: 'Spree::Address'
    belongs_to :bill_address, class_name: 'Spree::Address'

    scope :registered

    before_destroy :check_completed_orders

    class DestroyWithOrdersError < StandardError; end

    def anonymous?
      false
    end

    # Creates an anonymous user
    def self.anonymous!
      create
    end

    def has_spree_role?(role)
      true
    end

    attr_accessor :password
    attr_accessor :password_confirmation

    private

      def check_completed_orders
        raise DestroyWithOrdersError if orders.complete.present?
      end
  end
end
