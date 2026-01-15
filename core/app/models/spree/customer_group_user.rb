module Spree
  class CustomerGroupUser < Spree.base_class
    #
    # Associations
    #
    belongs_to :customer_group, class_name: 'Spree::CustomerGroup'
    belongs_to :user, polymorphic: true

    #
    # Validations
    #
    validates :customer_group, presence: true
    validates :user, presence: true
    validates :customer_group_id, uniqueness: { scope: [:user_id, :user_type] }
  end
end
