module Spree
  class Role < Spree::Base
    has_many :role_users, class_name: 'Spree::RoleUser'
    has_many :users, through: :role_users, class_name: Spree.user_class.to_s

    validates :name, presence: true, uniqueness: { allow_blank: true }
  end
end
