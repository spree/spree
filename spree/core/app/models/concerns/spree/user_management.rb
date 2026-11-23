module Spree
  # Included into whatever a role can govern — a Store today, a marketplace
  # seller later. Assignments hang off the resource's own roles, so a user is
  # "in" a resource exactly when they hold one of its roles.
  module UserManagement
    extend ActiveSupport::Concern

    included do
      has_many :roles, class_name: 'Spree::Role', as: :resource, dependent: :destroy
      has_many :role_users, through: :roles, source: :role_users
      has_many :users, through: :role_users, source: :user, source_type: Spree.admin_user_class.to_s
      has_many :invitations, class_name: 'Spree::Invitation', as: :resource, dependent: :destroy
    end

    # Adds a user to the resource with the default user role
    # If no role is provided, the default user role will be used
    # If a role is provided, it will be used instead of the default user role
    #
    # The role must be one this resource owns: a role names what it governs, so
    # granting another's here would add the user somewhere else entirely.
    #
    # @param user [Spree.admin_user_class] The user to add to the resource
    # @param role [Spree::Role] The role to add the user to
    # @raise [ArgumentError] if the role belongs to another resource
    # @return [Spree::RoleUser]
    def add_user(user, role = nil)
      role ||= default_user_role
      raise ArgumentError, "#{role.name} does not belong to this #{self.class.name}" unless role.resource == self

      role.role_users.find_or_create_by!(user: user)
    end

    # Revokes a user's access to the resource, including any invitation still
    # pending for them here, so they cannot rejoin by accepting it.
    # @param user [Spree.admin_user_class] The user to remove from the resource
    # @return [void]
    def remove_user(user)
      # Invitations first: an acceptance locks its invitation row, so this
      # waits for one in flight and then removes the role it granted.
      transaction do
        revoke_pending_invitations_for(user)
        # One DELETE, evaluated against the latest committed rows. A per-row
        # destroy first SELECTs from MySQL's repeatable-read snapshot, which
        # misses a role an acceptance committed while this waited on its lock.
        Spree::RoleUser.where(user: user, role: roles).delete_all
      end
    end

    # this can be overridden in the base model to use a different user role, eg. 'seller'
    def default_user_role
      Spree::Role.default_admin_role(self)
    end

    private

    # Matched by invitee and, case-insensitively, by email: an invitation sent
    # before the account existed carries only the address.
    def revoke_pending_invitations_for(user)
      pending = invitations.pending
      by_email = pending.where("LOWER(#{Spree::Invitation.table_name}.email) = LOWER(?)", user.email) if user.email.present?
      matching = pending.where(invitee: user)
      matching = matching.or(by_email) if by_email

      matching.destroy_all
    end
  end
end
