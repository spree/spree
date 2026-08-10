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
    include Spree::Metafields

    attribute :metadata, default: -> { {} }

    # A status column moved between values by a workflow — never a callback,
    # and never a state machine.
    has_status :pending, :verified, :expired, :revoked, default: :pending

    belongs_to :company, class_name: 'Spree::Company', inverse_of: :tax_exemption_certificates
    belongs_to :country, class_name: 'Spree::Country', optional: true
    belongs_to :state, class_name: 'Spree::State', optional: true
    belongs_to :verified_by, class_name: Spree.admin_user_class.to_s, optional: true

    # Confidential, so the private service rather than the public one that
    # serves product images.
    has_one_attached :document, service: Spree.private_storage_service_name

    validates :certificate_number, :reason_code, presence: true

    before_validation :resolve_state_code
    validate :state_belongs_to_country

    # Expiry is decided here rather than persisted: the date is the fact, and a
    # sweeper writing 'expired' would only restate it. Matches how gift cards
    # and stock reservations treat their own deadlines.
    scope :active, -> { verified.where('expires_at IS NULL OR expires_at > ?', Time.current) }
    scope :for_address, lambda { |address|
      where(country: [address&.country, nil].uniq).where(state: [address&.state, nil].uniq)
    }

    self.whitelisted_ransackable_attributes = %w[certificate_number reason_code status expires_at]

    delegate :store, :store_id, to: :company

    # The jurisdiction is written in the same vocabulary it is read in, mirroring
    # Spree::TaxRate. State abbreviations repeat across countries, so the state
    # is resolved in a callback once the country is known — a JSON body may name
    # the state first.
    def country_iso=(value)
      self.country = value.present? ? Spree::Country.by_iso(value) : nil
    end

    def state_code=(value)
      @state_code_input = value
    end

    # Accepting a certificate is a decision on record; withdrawing it is
    # revocation, not deletion.
    def can_be_deleted?
      !verified?
    end

    # Whether the date has passed, regardless of what the column says.
    def lapsed?
      expires_at.present? && expires_at <= Time.current
    end

    private

    def resolve_state_code
      return unless defined?(@state_code_input)

      self.state = @state_code_input.blank? ? nil : Spree::State.where(country_id: country_id).find_by(abbr: @state_code_input)
      remove_instance_variable(:@state_code_input)
    end

    # A certificate whose state sits in another country would never match an
    # address — the two columns have to agree.
    def state_belongs_to_country
      return if state.nil? || country.nil? || state.country_id == country_id

      errors.add(:state, :invalid)
    end
  end
end
