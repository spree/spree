module Spree
  # A user holding a role. Where the grant applies is the role's business —
  # `role.resource` names the store or vendor it governs — so an assignment
  # carries nothing but the pairing.
  class RoleUser < Spree.base_class
    #
    # Associations
    #
    belongs_to :role, class_name: 'Spree::Role', foreign_key: :role_id
    belongs_to :user, polymorphic: true
    belongs_to :invitation, class_name: 'Spree::Invitation', optional: true, inverse_of: :role_user

    #
    # Validations
    #
    validates :role, presence: true
    validates :user, presence: true
    validates :role_id, uniqueness: { scope: [:user_id, :user_type] }

    #
    # Delegations
    #
    delegate :name, to: :user
    delegate :resource, to: :role
  end
end
