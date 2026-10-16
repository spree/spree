module Spree
  # The exemption reasons one tax provider understands. Grouped so a merchant
  # with two engines installed can tell the vocabularies apart rather than
  # recording a code the engine calculating their tax has never heard of.
  class TaxExemptionReasonCodeGroup
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Offered when no provider registers a vocabulary, so a store with no tax
    # provider installed still has something to pick from. Core holds no
    # opinion beyond this: a provider registers the codes its own engine reads.
    DEFAULT_REASON_CODES = {
      'resale' => 'Resale',
      'government' => 'Government',
      'charitable' => 'Charitable',
      'educational' => 'Educational',
      'manufacturing' => 'Manufacturing',
      'agricultural' => 'Agricultural'
    }.freeze

    attribute :provider, :string
    attribute :reason_codes, default: -> { [] }

    # One group per provider registered in {Spree.tax_exemption_reason_codes},
    # or a single group of {DEFAULT_REASON_CODES} with no provider when none is.
    #
    # @return [Array<Spree::TaxExemptionReasonCodeGroup>]
    def self.all
      registered = Spree.tax_exemption_reason_codes
      return [build(nil, DEFAULT_REASON_CODES)] if registered.blank?

      registered.map { |provider, codes| build(provider.to_s, codes) }
    end

    # A provider registers either a hash of code to label, or a bare list when
    # each code is its own label.
    def self.build(provider, codes)
      pairs = codes.is_a?(Hash) ? codes : Array(codes).index_with(&:itself)
      reason_codes = pairs.map { |value, label| Spree::TaxExemptionReasonCode.new(value: value.to_s, label: label.to_s) }

      new(provider: provider, reason_codes: reason_codes)
    end
    private_class_method :build
  end
end
