module Spree
  class Invitation < Spree.base_class
    has_prefix_id :inv

    has_secure_token
    acts_as_paranoid

    #
    # Virtual Attributes
    #
    attribute :skip_email, :boolean, default: false

    #
    # Associations
    #
    belongs_to :resource, polymorphic: true # eg. Store, Seller, Account
    belongs_to :inviter, polymorphic: true # User or AdminUser
    belongs_to :invitee, polymorphic: true, optional: true # User or AdminUser
    belongs_to :role, class_name: 'Spree::Role'
    has_one :role_user, dependent: :nullify, class_name: 'Spree::RoleUser', inverse_of: :invitation

    #
    # Validations
    #
    validates :email, email: true, presence: true
    validates :token, presence: true, uniqueness: true
    validates :inviter, :resource, presence: true
    validate :invitee_is_not_inviter, on: :create
    validate :invitee_already_exists, on: :create
    validate :role_belongs_to_resource

    #
    # Scopes
    #
    scope :pending, -> { where(status: 'pending') }
    scope :accepted, -> { where(status: 'accepted') }
    scope :not_expired, -> { where('expires_at > ?', Time.current) }

    #
    # Status
    #
    # No state machine — acceptance runs through Spree::Invitations::Accept
    # (docs/plans/6.0-service-workflows.md), which checks the expiry window
    # and the invitee before it writes. Those were state-scoped validations
    # on the machine's `accepted` state; as workflow guards they refuse the
    # acceptance outright instead of leaving a record that fails to save.
    include Spree::HasStatus
    has_status :pending, :accepted, default: :pending

    #
    # Callbacks
    #
    after_initialize :set_defaults, if: :new_record?
    before_validation :set_role_and_resource, if: :new_record?
    before_validation :set_invitee_from_email, on: :create
    after_commit :publish_invitation_created_event, on: :create, unless: :skip_email

    # returns the store for the invitation
    # if the resource is a store, return the resource
    # if the resource responds to store, return the store
    # otherwise, return the current store
    # @return [Spree::Store]
    def store
      if resource.is_a?(Spree::Store)
        resource
      elsif resource.respond_to?(:store)
        resource.store
      else
        Spree::Store.current
      end
    end

    # returns true if the invitation has expired
    # @return [Boolean]
    def expired?
      expires_at < Time.current
    end

    # @deprecated Call Spree.invitation_accept_workflow — removed in 6.1.
    def accept
      Spree::Deprecation.warn('Spree::Invitation#accept is deprecated and will be removed in Spree 6.1. Call Spree.invitation_accept_workflow instead.')
      Spree.invitation_accept_workflow.call(invitation: self).success?
    end

    # @deprecated Call Spree.invitation_accept_workflow — removed in 6.1.
    def accept!
      Spree::Deprecation.warn('Spree::Invitation#accept! is deprecated and will be removed in Spree 6.1. Call Spree.invitation_accept_workflow instead.')
      result = Spree.invitation_accept_workflow.call(invitation: self)

      if result.failure?
        # ResultError#to_s unwraps an ActiveModel::Errors into its full
        # messages; its `value` would inspect the object into the message.
        errors.add(:base, result.error.to_s)
        raise ActiveRecord::RecordInvalid, self
      end

      true
    end

    # Resends the invitation email if the invitation is pending and not expired
    def resend!
      return if expired? || deleted? || accepted?

      publish_event('invitation.resent')
    end

    private

    def publish_invitation_created_event
      publish_event('invitation.created')
    end

    # This method is kept for backwards compatibility.
    # Email sending is now handled by the InvitationEmailSubscriber via the 'invitation.accept' event.
    def send_acceptance_notification
      # no-op - email is sent via event subscriber
    end

    def set_defaults
      self.expires_at ||= 2.weeks.from_now
    end

    # A role names what it governs, so the invitation follows it — one carrying
    # another resource's role would grant access somewhere the inviter never
    # named. Resolved at validation rather than on initialize, since a caller's
    # own `resource` is not assigned yet when the record is instantiated.
    def set_role_and_resource
      self.resource ||= role&.resource || Spree::Store.current
      self.role ||= Spree::Role.default_admin_role(resource)
    end

    def invitee_is_not_inviter
      if invitee == inviter
        errors.add(:invitee, :same_as_inviter, message: Spree.t('errors.messages.same_as_inviter'))
      end
    end

    # Accepting the invitation grants the role, which carries its own resource
    # — so a mismatch would hand out access to somewhere else entirely.
    def role_belongs_to_resource
      return if role.blank? || resource.blank?
      return if role.resource == resource

      errors.add(:role, :invitation_role_resource_mismatch, message: Spree.t(:invitation_role_resource_mismatch))
    end

    def invitee_already_exists
      return if resource.blank?

      # Check role_users directly for better performance and to avoid potential source_type issues
      user_to_check = invitee || Spree.admin_user_class.find_by(email: email)
      return if user_to_check.blank?

      if resource.role_users.exists?(user: user_to_check)
        errors.add(:email, :already_a_member, message: Spree.t('errors.messages.already_a_member'))
      end
    end

    def set_invitee_from_email
      return if invitee.present?

      self.invitee = Spree.admin_user_class.find_by(email: email)
    end
  end
end
