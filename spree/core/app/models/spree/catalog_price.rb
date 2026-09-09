module Spree
  # What a buyer on one catalog pays for one variant, and where that number
  # came from. Resolved by {Spree::Catalogs::ResolvePrices}; this object is
  # only the answer.
  #
  # The source is the point: an amount alone cannot tell a merchant whether
  # their agreement actually prices a product or is quietly falling through
  # to the shop price (docs/plans/6.0-catalog-agreement-rework.md).
  #
  #   explicit  — an amount someone typed on the catalog's own list
  #   automatic — that list's percentage applied to the base price
  #   base      — the variant's normal price; this agreement does not price it
  class CatalogPrice
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Where a resolved amount came from. A closed set: the reading is only
    # useful if every amount can say which of the three it is.
    SOURCES = %w[explicit automatic base].freeze

    attribute :amount, :decimal
    attribute :currency, :string
    attribute :source, :string
    # How many quantity tiers sit above this amount — breaks on the list's own
    # rows, or bands on its percentage. Zero for a variant priced at one
    # figure whatever the order size (docs/plans/6.0-volume-pricing.md).
    attribute :break_count, :integer, default: 0

    # The ladder itself, as {Spree::CatalogPriceTier} rows ordered by quantity
    # — so a merchant reading the agreement sees what the buyer pays at each
    # threshold without opening the price sheet
    # (docs/plans/6.0-volume-pricing.md).
    # The variant this amount prices. Carried so the reading can be addressed
    # by the thing a client acts on — a resolved price has no id of its own,
    # but the variant it belongs to does
    # (docs/plans/6.0-volume-pricing.md).
    attr_accessor :variant

    attr_writer :tiers

    validates :source, inclusion: { in: SOURCES }

    # @return [Array<Spree::CatalogPriceTier>]
    def tiers
      @tiers ||= []
    end

    # The priced variant, as the API addresses it. A resolved price has no id
    # of its own, so the variant's is what a client would act on
    # (docs/plans/6.0-volume-pricing.md).
    #
    # @return [String, nil]
    def prefixed_id
      variant&.prefixed_id
    end

    # What distinguishes this variant from its siblings — "Color: White".
    # Blank for a product whose single variant has no options to name.
    #
    # @return [String, nil]
    def label
      variant&.options_text.presence
    end

    # @return [String, nil]
    def sku
      variant&.sku
    end

    # True when the catalog's own pricing decided this amount, rather than the
    # shop price showing through.
    # @return [Boolean]
    def from_agreement?
      source != 'base'
    end

    # Whether the amount is the bottom of a ladder rather than the only price.
    # @return [Boolean]
    def tiered?
      break_count.to_i.positive?
    end

    # The amount as the wire carries it — see CatalogPriceTier#display_value.
    #
    # @return [String]
    def display_value
      amount.to_s
    end

    # @return [Spree::Money]
    def money
      Spree::Money.new(amount, currency: currency)
    end

    # @return [String]
    def display_amount
      money.to_s
    end
  end
end
