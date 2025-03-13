module Spree
  class RoleUser < Spree.base_class
    belongs_to :role, class_name: 'Spree::Role'
    belongs_to :user, polymorphic: true
  end
end
