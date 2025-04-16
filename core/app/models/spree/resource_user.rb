module Spree
  class ResourceUser < Spree.base_class
    #
    # Associations
    #
    belongs_to :resource, polymorphic: true # Store, Vendor, etc
    belongs_to :user, polymorphic: true # Spree::User, Spree::AdminUser, etc
    belongs_to :invitation, optional: true # Spree::Invitation, if the resource_user was created from an invitation
    has_many :invitation_roles, through: :invitation, source: :roles

    #
    # Validations
    #
    validates :resource_id, uniqueness: { scope: [:resource_type, :user_id, :user_type] }

    #
    # Scopes
    #
    scope :by_resource, ->(resource) { where(resource: resource) }
    scope :by_user, ->(user) { where(user: user) }

    #
    # Callbacks
    #
    after_create :set_roles
    after_destroy :revoke_roles

    private

    def set_roles
      return if invitation.blank?

      user.spree_roles = invitation_roles
      user.save!
    end

    def revoke_roles
      return if invitation.blank?

      user.spree_roles.where(id: invitation_role_ids).destroy_all
    end
  end
end
