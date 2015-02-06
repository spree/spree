module Spree
  class Role < Spree::Base
    has_and_belongs_to_many :users, join_table: 'spree_roles_users', class_name: Spree.user_class.to_s

    validates :name, presence: true
  end
end
