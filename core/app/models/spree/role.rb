module Spree
  class Role < Spree.base_class
    include Spree::UniqueName

    ADMIN_ROLE = 'admin'

    has_many :role_users, class_name: 'Spree::RoleUser', dependent: :destroy
    has_many :users, through: :role_users, class_name: "::#{Spree.user_class}"
  end
end
