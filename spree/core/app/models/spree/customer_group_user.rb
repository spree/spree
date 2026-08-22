module Spree
  class CustomerGroupUser < Spree.base_class
    #
    # Associations
    #
    belongs_to :customer_group, class_name: 'Spree::CustomerGroup'
    belongs_to :customer, polymorphic: true

    include Spree::DeprecatedCustomerAlias
    alias_attribute :user_type, :customer_type

    #
    # Validations
    #
    validates :customer, presence: true
    validates :customer_group_id, uniqueness: { scope: [:customer_id, :customer_type] }
  end
end
