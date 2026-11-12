module Spree
  # Why a business buys without tax — "Resale", "Government", "Charitable
  # organisation". Certificates point at a reason the way products point at a
  # tax category: the `name` is the merchant's own wording, and the `code` is
  # what a tax engine reads. Spree's own engine only keeps the code for
  # reference, while an external one (Avalara's entity use codes) decides the
  # exemption by it, so changing the code changes what every certificate
  # holding the reason sends from then on.
  class TaxExemptionReason < Spree.base_class
    has_prefix_id :txr

    include Spree::NamedType
    include Spree::Metadata

    # Guarded by hand rather than with :restrict_with_error, which would also
    # refuse when the whole store is being destroyed.
    has_many :tax_exemption_certificates, class_name: 'Spree::TaxExemptionCertificate',
                                          inverse_of: :tax_exemption_reason, dependent: nil

    self.whitelisted_ransackable_attributes = %w[name code active]

    # Upper case because tax engines read codes case-insensitively: `g` and
    # `G` would be two reasons here and one to Avalara.
    normalizes :code, with: ->(value) { value.to_s.strip.upcase.presence }

    validates :code, presence: true, length: { maximum: 64 }
    validates_store_uniqueness :code

    before_destroy :ensure_unused

    # Finds the reason already holding the code, else the one holding the
    # name, so seeding a store never collides with a reason the merchant added
    # or renamed. Code first: it is what a tax engine reads, so a match on it
    # is the same reason whatever the merchant called it.
    #
    # @param code [String]
    # @param name [String]
    # @return [Spree::TaxExemptionReason]
    def self.find_or_create_by_code_or_name!(code:, name:)
      code = normalize_value_for(:code, code)

      find_by(code: code) || find_by(name: name) || create!(code: code, name: name)
    end

    # Mirrors the destroy guard, so the dashboard can hide the delete control
    # rather than offer one the model will refuse.
    #
    # @return [Boolean]
    def can_be_deleted?
      !tax_exemption_certificates.exists?
    end

    private

    def ensure_unused
      return if destroyed_by_association.present? || can_be_deleted?

      errors.add(:base, :in_use)
      throw :abort
    end
  end
end
