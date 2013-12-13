# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
module Spree
  class LegacyUser < ActiveRecord::Base
    include Core::UserAddress

    self.table_name = 'spree_users'
    has_many :orders, foreign_key: :user_id

    before_destroy :check_completed_orders

    class DestroyWithOrdersError < StandardError; end

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
