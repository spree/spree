module Spree
  # An email invited into a company that matches no store customer yet.
  # Memberships stay always-active and customer-backed, so the pending state
  # lives here (mirroring the staff invitation shape): acceptance registers
  # the customer through the customer-creation workflow — or binds an
  # already-authenticated one — and lands as a {Spree::CompanyMembership}.
  #
  # The token is plaintext, like the staff invitation and setup tokens. It
  # grants exactly what a direct membership grants — no roles; Enterprise
  # attaches its role payload through +metadata+ and applies it on the
  # +company_invitation.accepted+ event.
  class CompanyInvitation < Spree.base_class
    has_prefix_id :cinv

    include Spree::Metadata

    publishes_lifecycle_events

    EXPIRY = 30.days

    has_secure_token :token

    belongs_to :company, class_name: 'Spree::Company', inverse_of: :invitations
    # nil when staff invites from the dashboard.
    belongs_to :inviter, class_name: Spree.customer_class.to_s, optional: true
    # Bound at acceptance.
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email, presence: true, email: true
    validates :email, uniqueness: { scope: :company_id, conditions: -> { pending } }

    after_initialize :set_default_expiry, if: :new_record?

    # Re-inviting after expiry or revocation is allowed, which is why expired
    # rows fall out of +pending+ rather than merely being unusable.
    scope :pending, -> { where(accepted_at: nil, revoked_at: nil).where(arel_table[:expires_at].gt(Time.current)) }

    delegate :store, :store_id, to: :company

    self.whitelisted_ransackable_attributes = %w[email]

    # @return [Boolean]
    def pending?
      accepted_at.nil? && revoked_at.nil? && !expired?
    end

    # @return [Boolean]
    def accepted?
      accepted_at.present?
    end

    # @return [Boolean]
    def revoked?
      revoked_at.present?
    end

    # @return [Boolean]
    def expired?
      expires_at < Time.current
    end

    # Withdraws a pending invitation; its token then 404s on lookup.
    #
    # @return [Boolean]
    def revoke!
      return false unless pending?

      update!(revoked_at: Time.current)
      publish_event('company_invitation.revoked')
      true
    end

    private

    def set_default_expiry
      self.expires_at ||= EXPIRY.from_now
    end
  end
end
