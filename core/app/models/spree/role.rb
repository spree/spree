class Spree::Role < ActiveRecord::Base
<<<<<<< HEAD
  has_and_belongs_to_many :users, :join_table => 'spree_roles_users'
=======
  has_and_belongs_to_many :users
>>>>>>> Namespace top-level core models
end
