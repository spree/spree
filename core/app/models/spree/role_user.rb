module Spree
  class RoleUser < Spree::Base
    self.table_name = 'spree_roles_users'

    belongs_to :role, class_name: 'Spree::Role'
    belongs_to :user, class_name: Spree::User.to_s
  end
end
