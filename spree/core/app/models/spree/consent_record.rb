module Spree
  # Proof that a person accepted something at a moment in time.
  #
  # GDPR Art. 7(1) puts the burden of demonstrating consent on the controller,
  # and a boolean on the customer cannot carry that burden: it says what is
  # true now, not what was agreed when. So acceptance is recorded as an event.
  # A person consents more than once — at registration, then again at each
  # checkout — and each occasion is its own row.
  #
  # The owner is a customer where one exists and the cart or order otherwise,
  # because guest checkout produces consent with no account behind it.
  class ConsentRecord < Spree.base_class
    has_prefix_id :consent

    include Spree::SingleStoreResource

    # What was agreed to. An open set: a store with its own consent gesture
    # records it under its own purpose without reopening this class.
    TERMS_OF_SERVICE = 'terms_of_service'.freeze
    EMAIL_MARKETING = 'email_marketing'.freeze

    # Where the gesture happened.
    CHECKOUT = 'checkout'.freeze
    REGISTRATION = 'registration'.freeze
    ACCOUNT = 'account'.freeze
    # Core's own: erasure withdraws marketing consent on the person's behalf,
    # and that withdrawal is a consent event like any other.
    ANONYMIZATION = 'anonymization'.freeze

    SOURCES = [CHECKOUT, REGISTRATION, ACCOUNT, ANONYMIZATION, 'admin', 'import', 'storefront'].freeze

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :owner, polymorphic: true

    validates :purpose, presence: true
    validates :source, presence: true, inclusion: { in: SOURCES }
    validates :recorded_at, presence: true

    scope :for_purpose, ->(purpose) { where(purpose: purpose.to_s) }
    scope :accepted, -> { where(accepted: true) }
    scope :withdrawn, -> { where(accepted: false) }
    scope :recent_first, -> { order(recorded_at: :desc) }

    self.whitelisted_ransackable_attributes = %w[purpose source accepted email recorded_at]

    before_validation :set_recorded_at, on: :create

    # Records acceptance of the store's consent-gated policies, snapshotting
    # each document as it read at the time. The digest is what makes the row
    # evidence rather than an assertion: a merchant who later edits their
    # terms can still show which text this person agreed to.
    #
    # @param store [Spree::Store]
    # @param owner [Spree::Customer, Spree::Order] the consenting party
    # @param purpose [String]
    # @param source [String] one of SOURCES
    # @param accepted [Boolean]
    # @param email [String, nil]
    # @param ip_address [String, nil]
    # @param user_agent [String, nil]
    # @param policies [Array<Spree::Policy>, nil] documents shown at the time
    # @return [Spree::ConsentRecord]
    def self.record!(store:, owner:, purpose:, source:, accepted: true, email: nil,
                     ip_address: nil, user_agent: nil, policies: nil)
      create!(
        store: store,
        owner: owner,
        purpose: purpose.to_s,
        source: source.to_s,
        accepted: accepted,
        email: email,
        ip_address: ip_address,
        user_agent: user_agent,
        documents: policies.present? ? policies.map { |policy| document_snapshot(policy) } : nil
      )
    end

    # The document as it read at the moment of agreement.
    #
    # Stores the body itself, not only a hash of it. A digest can show that a
    # policy has since changed, but it cannot say what the person actually
    # read — and reproducing the text they agreed to is the whole point of
    # keeping the row. The digest rides along as a cheap equality check.
    #
    # The locale is recorded because policies are translated: the same document
    # is different text in each language.
    #
    # @param policy [Spree::Policy]
    # @return [Hash]
    def self.document_snapshot(policy)
      body = policy.body.to_s

      {
        'slug' => policy.slug,
        'name' => policy.name,
        'locale' => Spree::Current.locale || I18n.locale.to_s,
        'body' => body,
        'digest' => Digest::SHA256.hexdigest(body),
        'updated_at' => policy.updated_at&.iso8601
      }
    end

    # @return [Array<Hash>]
    def documents_list
      Array(documents)
    end

    private

    def set_recorded_at
      self.recorded_at ||= Time.current
    end
  end
end
