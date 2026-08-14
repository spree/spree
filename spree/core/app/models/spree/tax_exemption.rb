module Spree
  # A claim that a sale, or part of one, is exempt from tax — resale,
  # government purchase, a charity's own use. Ephemeral evidence handed to a
  # tax provider through {Spree::TaxProvider::Base#estimate}, never persisted:
  # the claim is the input, the zero-amount TaxLine rows are the record.
  #
  # Exemption is per jurisdiction (a certificate valid in one state and not the
  # next) and per item (a resale order can hold own-use lines), which is why
  # this is a scoped entry rather than a flag. One entry per certificate.
  class TaxExemption
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Why the sale is exempt, in the provider's vocabulary — Avalara's
    # entityUseCode territory.
    attribute :reason_code, :string
    attribute :certificate_number, :string

    # Where the claim holds. Nil country = everywhere the provider taxes,
    # nil state = the whole country.
    attribute :country_iso, :string
    attribute :state_code, :string

    # Per-line departures from the entry. Empty = the whole order is claimed.
    attribute :item_overrides, default: -> { [] }

    validates :reason_code, presence: true
    validate :item_overrides_can_name_their_item

    # Whether this entry claims exemption for the given item.
    #
    # @param item [Spree::LineItem, Spree::Fulfillment, Spree::Fee]
    # @return [Boolean]
    def covers_item?(item)
      override = override_for(item)
      return override.exempt? unless override.nil?

      true
    end

    # Whether this entry's scope reaches the given jurisdiction. An entry with
    # no country claims every jurisdiction; one with a country but no state
    # claims every state within it.
    #
    # @param country_iso [String, nil]
    # @param state_code [String, nil]
    # @return [Boolean]
    def covers_jurisdiction?(country_iso, state_code = nil)
      return true if self.country_iso.blank?
      return false unless self.country_iso.casecmp?(country_iso.to_s)
      return true if self.state_code.blank?

      self.state_code.casecmp?(state_code.to_s)
    end

    # The reason to record for an item — the per-line override's when it names
    # one, the entry's otherwise.
    #
    # @param item [Spree::LineItem, Spree::Fulfillment, Spree::Fee]
    # @return [String, nil]
    def reason_code_for(item)
      override_for(item)&.reason_code.presence || reason_code
    end

    private

    # An override that cannot say which line it applies to does not narrow this
    # entry — it widens it. #override_for never matches it, so #covers_item?
    # falls through to true for every line and a per-line carve-out becomes an
    # order-wide exemption.
    def item_overrides_can_name_their_item
      return if Array(item_overrides).all? { |override| override.try(:item_id).present? }

      errors.add(:item_overrides, :invalid)
    end

    def override_for(item)
      item_overrides.to_a.find { |override| override.item_id.to_s == item.prefixed_id.to_s }
    end
  end
end
