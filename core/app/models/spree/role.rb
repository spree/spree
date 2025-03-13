module Spree
  class Role < Spree.base_class
    include Spree::UniqueName

    ADMIN_ROLE = 'admin'

    has_many :role_users, class_name: 'Spree::RoleUser', dependent: :destroy
    has_many :users, through: :role_users, source: :user, source_type: Spree.user_class.to_s
    has_many :admin_users, through: :role_users, source: :user, source_type: Spree.admin_user_class.to_s
  end
end
