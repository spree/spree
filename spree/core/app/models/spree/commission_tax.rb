# frozen_string_literal: true

module Spree
  # How a commission is taxed: the rate, and the treatment that explains it.
  #
  # Ephemeral — the record is the columns this stamps onto a
  # {Spree::CommissionLine}. It exists because a rate alone cannot answer the
  # question an invoice asks: 21% is a figure, "standard rated in DE" is a
  # justification, and a marketplace billing sellers across borders needs the
  # second one as much as the first.
  #
  # Deliberately not a {Spree::TaxLine}. Same shape, opposite side of the
  # ledger: a tax line is tax the customer pays on goods and sums into the
  # order total, while this is tax the platform charges a seller on its own
  # fee, and must never reach what the shopper is billed.
  class CommissionTax
    include ActiveModel::Model
    include ActiveModel::Attributes

    # The fraction applied to the fee — 0.21 for 21%.
    attribute :rate, :decimal, default: 0

    # Why the fee was taxed this way, in {Spree::TaxLine}'s vocabulary.
    attribute :taxability_reason, :string

    # Where it was taxed: the seller's own jurisdiction, since the platform
    # invoices the seller's business rather than the shopper's address.
    attribute :country_code, :string
    attribute :state_code, :string

    # A fee nobody taxes. Distinct from "taxed at zero", which is a treatment a
    # jurisdiction chose and an invoice has to show.
    #
    # @return [Spree::CommissionTax]
    def self.untaxed
      new(rate: 0)
    end

    # The columns this stamps onto a commission line.
    #
    # @return [Hash]
    def to_line_attributes
      {
        tax_rate: rate,
        taxability_reason: taxability_reason,
        country_code: country_code,
        state_code: state_code
      }
    end
  end
end
