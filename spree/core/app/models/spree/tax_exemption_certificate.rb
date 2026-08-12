module Spree
  # A business customer's evidence that some or all of its purchases are not
  # taxed — a resale certificate, a government exemption, a charity's own-use
  # claim. Resolved into ephemeral {Spree::TaxExemption} entries at estimate
  # time; the zero-amount tax rows a provider writes are the durable record of
  # what was claimed.
  #
  # Scoped by jurisdiction rather than duplicated per branch: a certificate
  # valid in one state and not the next is the ordinary case, and the country
  # and state columns say exactly where it holds.
  class TaxExemptionCertificate < Spree.base_class
    has_prefix_id :cert

    include Spree::HasStatus
    include Spree::HasCustomFields
    include Spree::Metadata

    # A status column moved between values by a workflow — never a callback,
    # and never a state machine.
    has_status :pending, :verified, :expired, :revoked, default: :pending

    belongs_to :company, class_name: 'Spree::Company', inverse_of: :tax_exemption_certificates
    belongs_to :verified_by, class_name: Spree.admin_user_class.to_s, optional: true

    # Confidential, so the private service rather than the public one that
    # serves product images.
    has_one_attached :document, service: Spree.private_storage_service_name

    validates :certificate_number, :reason_code, presence: true

    # Where the certificate holds, as codes: a blank country_iso claims every
    # country, and a country with no state_code claims all of its states.
    # Upcased on the way in, and unknown codes are kept as entered — a code
    # nothing recognises must narrow the certificate to nothing, never widen it
    # to everywhere, which is what resolving it to a nil country used to do.
    normalizes :country_iso, :state_code, with: ->(value) { value.presence&.to_s&.upcase }

    # Expiry is decided here rather than persisted: the date is the fact, and a
    # sweeper writing 'expired' would only restate it. Matches how gift cards
    # and stock reservations treat their own deadlines.
    scope :active, -> { verified.where('expires_at IS NULL OR expires_at > ?', Time.current) }
    scope :expired, -> { where(status: 'expired').or(where('expires_at <= ?', Time.current)) }
    # No address means no jurisdiction to match, which is not the same as
    # "matches the certificates valid everywhere" — a swapped-in resolver
    # calling this without a destination must not be handed a claim.
    scope :for_address, lambda { |address|
      next none if address.nil?

      where(country_iso: [address.country_iso.presence, nil].uniq).
        where(state_code: [address.state_abbr.presence, nil].uniq)
    }

    self.whitelisted_ransackable_attributes = %w[certificate_number reason_code status expires_at]

    delegate :store, :store_id, to: :company

    # Accepting a certificate is a decision on record; withdrawing it is
    # revocation, not deletion.
    def can_be_deleted?
      !verified?
    end

    # Whether the date has passed, regardless of what the column says.
    def lapsed?
      expires_at.present? && expires_at <= Time.current
    end

    # Nothing writes the 'expired' status — the date is the fact — so the
    # predicate and scope HasStatus generated would answer false and empty
    # forever. Both derive instead, the way Spree::GiftCard does, so a caller
    # reaching for the obvious name gets the truth.
    def expired?
      status == 'expired' || lapsed?
    end

    private

  end
end
