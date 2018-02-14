module Spree
  class RoleUser < Spree::Base
    belongs_to :role, class_name: 'Spree::Role'
    belongs_to :user, class_name: Spree.user_class.to_s
  end
end
