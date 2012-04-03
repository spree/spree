module Spree
  class Role < ActiveRecord::Base
    has_and_belongs_to_many :users, :join_table => 'spree_roles_users'
    attr_accessible :name
  end
end
