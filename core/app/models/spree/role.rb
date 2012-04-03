module Spree
  class Role < ActiveRecord::Base
    attr_accessible :name

    has_and_belongs_to_many :users, :join_table => 'spree_roles_users'
  end
end
