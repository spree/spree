module Spree
  class RoleUser < Spree::Base
    belongs_to :role
    belongs_to :user, class_name: Spree.user_class
  end
end
