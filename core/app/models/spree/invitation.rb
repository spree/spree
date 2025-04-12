module Spree
  class Invitation < Base
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
    belongs_to :invitee, polymorphic: true # User or AdminUser
    has_many :invitation_roles, dependent: :destroy
    has_many :roles, through: :invitation_roles

    #
    # Validations
    #
    validates :email, email: true, presence: true
    validates :token, presence: true, uniqueness: true
    validates :inviter, :resource, :roles, presence: true
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
      event :accept do
        transition :pending => :accepted
      end
      after_transition to: :accepted, do: [:set_accepted_at, :send_acceptance_notification]
    end

    #
    # Callbacks
    #
    after_initialize :set_defaults, if: :new_record?
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

    def resend!
      return if expired? || deleted? || accepted?

      send_invitation_email
    end

    private

    def send_invitation_email
      Spree::InvitationMailer.invitation_email(self).deliver_later
    end

    def send_acceptance_notification
      Spree::InvitationMailer.invitation_accepted(self).deliver_later
    end

    def set_defaults
      self.expires_at ||= 2.weeks.from_now
    end

    def invitee_is_not_inviter
      if invitee == inviter
        errors.add(:invitee, 'cannot be the same as the inviter')
      end
    end

    def invitee_already_exists
      exists = if invitee.present?
                store.admin_users.include?(invitee)
              else
                store.admin_users.exists?(email: email)
              end

      if exists
        errors.add(:email, 'already exists')
      end
    end

    def set_accepted_at
      update!(accepted_at: Time.current)
    end
  end
end
