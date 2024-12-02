module Spree
  class RoleUser < Spree.base_class
    belongs_to :role, class_name: 'Spree::Role'
    belongs_to :user, class_name: Spree.admin_user_class.to_s
  end
end
