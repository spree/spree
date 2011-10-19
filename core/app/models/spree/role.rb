class Spree::Role < ActiveRecord::Base
  has_and_belongs_to_many :users, :class_name => 'Spree::User',
                                  :join_table => 'spree_roles_users'
end
