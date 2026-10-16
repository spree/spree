module Spree
  # Why a business buys without tax — "Resale", "Government", "Charitable
  # organisation". Recorded on a {Spree::TaxExemptionCertificate} by its
  # `code`, which is what a tax engine reads: Spree's own engine only keeps
  # it for reference, while an external one (Avalara's entity use codes)
  # decides the exemption by it. The `name` is the merchant's own wording.
  class TaxExemptionReason < Spree.base_class
    has_prefix_id :txr

    include Spree::NamedType
    include Spree::Metadata

    self.whitelisted_ransackable_attributes = %w[name code active]

    normalizes :code, with: ->(value) { value&.to_s&.strip&.presence }

    validates :code, presence: true, length: { maximum: 64 }
    validates_store_uniqueness :code
    validate :code_unchanged_while_in_use, on: :update

    before_destroy :ensure_unused

    # The certificates recording this reason. They hold the code rather than
    # a reference, because the code is what the tax engine reads.
    #
    # @return [ActiveRecord::Relation<Spree::TaxExemptionCertificate>]
    def certificates
      Spree::TaxExemptionCertificate.joins(:company).
        where(reason_code: code_in_database, Spree::Company.table_name => { store_id: store_id })
    end

    # Mirrors the destroy guard, so the dashboard can hide the delete control
    # rather than offer one the model will refuse.
    #
    # @return [Boolean]
    def can_be_deleted?
      !certificates.exists?
    end

    private

    # Renaming the code would leave every certificate that holds it pointing at
    # a reason that no longer exists, so a code in use is fixed.
    def code_unchanged_while_in_use
      return unless will_save_change_to_code? && certificates.exists?

      errors.add(:code, :in_use)
    end

    def ensure_unused
      return if destroyed_by_association.present? || can_be_deleted?

      errors.add(:base, :in_use)
      throw :abort
    end
  end
end
