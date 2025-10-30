module Spree
  class Invitation < Spree.base_class
    has_secure_token
    acts_as_paranoid

    #
    # Virtual Attributes
    #
    attribute :skip_email, :boolean, default: false

    #
    # Associations
    #
    belongs_to :resource, polymorphic: true # eg. Store, Vendor, Account
    belongs_to :inviter, polymorphic: true # User or AdminUser
    belongs_to :invitee, polymorphic: true, optional: true # User or AdminUser
    belongs_to :role, class_name: 'Spree::Role'
    has_one :role_user, dependent: :nullify, class_name: 'Spree::RoleUser', inverse_of: :invitation

    #
    # Validations
    #
    validates :email, email: true, presence: true
    validates :token, presence: true, uniqueness: true
    validates :inviter, :resource, :role, presence: true
    validate :invitee_is_not_inviter, on: :create
    validate :invitee_already_exists, on: :create

    #
    # Scopes
    #
    scope :pending, -> { where(status: 'pending') }
    scope :accepted, -> { where(status: 'accepted') }
    scope :not_expired, -> { where('expires_at > ?', Time.current) }

    #
    # State Machine
    #
    state_machine initial: :pending, attribute: :status do
      state :accepted do
        validate :accept_invitation_within_time_limit
        validates :invitee, presence: true
      end

      event :accept do
        transition pending: :accepted
      end
      after_transition to: :accepted, do: :after_accept
    end

    #
    # Callbacks
    #
    after_initialize :set_defaults, if: :new_record?
    before_validation :set_invitee_from_email, on: :create
    after_create :send_invitation_email, unless: :skip_email

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

    # Resends the invitation email if the invitation is pending and not expired
    def resend!
      return if expired? || deleted? || accepted?

      send_invitation_email
    end

    private

    # this method can be extended by developers now
    def after_accept
      create_role_user
      set_accepted_at
      send_acceptance_notification
    end

    def send_invitation_email
      Spree::InvitationMailer.invitation_email(self).deliver_later
    end

    def send_acceptance_notification
      Spree::InvitationMailer.invitation_accepted(self).deliver_later
    end

    def set_defaults
      self.expires_at ||= 2.weeks.from_now
      self.resource ||= Spree::Store.current
      self.role ||= Spree::Role.default_admin_role
    end

    def invitee_is_not_inviter
      if invitee == inviter
        errors.add(:invitee, 'cannot be the same as the inviter')
      end
    end

    def invitee_already_exists
      return if resource.blank?

      exists = if invitee.present?
                resource.users.include?(invitee)
              else
                resource.users.exists?(email: email)
              end

      if exists
        errors.add(:email, 'already exists')
      end
    end

    def set_accepted_at
      update!(accepted_at: Time.current)
    end

    def create_role_user
      return if invitee.blank?

      role_user = resource.add_user(invitee, role)
      self.role_user = role_user
      save!
    end

    def set_invitee_from_email
      return if invitee.present?

      self.invitee = Spree.admin_user_class.find_by(email: email)
    end

    def accept_invitation_within_time_limit
      if Time.current > expires_at
        errors.add(:base, 'Invitation expired')
      end
    end
  end
end
