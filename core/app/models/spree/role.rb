module Spree
  class Role < ActiveRecord::Base
    attr_accessible :name

    has_and_belongs_to_many :users, :join_table => 'spree_roles_users', :class_name => Spree.user_class.to_s
    has_and_belongs_to_many :products, :join_table => 'spree_restrictions'
  end
end
