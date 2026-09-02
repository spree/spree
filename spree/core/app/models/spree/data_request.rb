module Spree
  # A GDPR data subject request: access (Art. 15) or erasure (Art. 17).
  #
  # The record exists so a request leaves a trace. A response that was
  # streamed and forgotten proves nothing, and Art. 30 record-keeping asks a
  # controller to show which requests arrived and how they were answered.
  # It also serves as the cooldown: a pending request is returned rather than
  # starting a second build, so a customer cannot queue an unbounded number
  # of expensive exports.
  #
  # Erasure is carried out by Spree::Customers::Anonymize; this model records
  # that it was asked for and when it finished.
  class DataRequest < Spree.base_class
    has_prefix_id :dsr

    include Spree::SingleStoreResource
    include Spree::NumberIdentifier

    has_spree_number prefix: 'DSR'

    publishes_lifecycle_events

    include Spree::HasStatus
    has_status :pending, :processing, :completed, :failed, default: :pending

    ACCESS = 'access'.freeze
    ERASURE = 'erasure'.freeze
    KINDS = [ACCESS, ERASURE].freeze

    # How long a generated export stays downloadable. Long enough for a person
    # to act on the email, short enough that a copy of everything a shop knows
    # about them is not left lying around.
    DEFAULT_EXPIRY = 7.days

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :customer, class_name: Spree.customer_class.to_s
    # Null when the subject asked for it themselves; set when staff acted on a
    # request that arrived by email.
    belongs_to :requested_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_one_attached :export_file, service: Spree.private_storage_service_name

    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :email, presence: true
    validates :requested_at, presence: true

    scope :access, -> { where(kind: ACCESS) }
    scope :erasure, -> { where(kind: ERASURE) }
    scope :in_progress, -> { with_status(:pending, :processing) }
    scope :recent_first, -> { order(requested_at: :desc) }

    self.whitelisted_ransackable_attributes = %w[number kind status email requested_at completed_at]
    self.whitelisted_ransackable_scopes = %w[access erasure in_progress]

    before_validation :set_defaults, on: :create

    # @return [Boolean] a request for a copy of the data (Art. 15)
    def access?
      kind == ACCESS
    end

    # @return [Boolean] a request to erase it (Art. 17)
    def erasure?
      kind == ERASURE
    end

    # Whether the generated file is still downloadable.
    # @return [Boolean]
    def downloadable?
      completed? && export_file.attached? && !expired?
    end

    # @return [Boolean]
    def expired?
      expires_at.present? && expires_at.past?
    end

    private

    def set_defaults
      self.requested_at ||= Time.current
      self.email ||= customer&.email
    end
  end
end
