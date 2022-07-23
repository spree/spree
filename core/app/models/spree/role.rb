module Spree
  class Role < Spree::Base
    include UniqueName

    has_many :role_users, class_name: 'Spree::RoleUser', dependent: :destroy
    has_many :users, through: :role_users, class_name: "::#{Spree.user_class}"
  end
end
