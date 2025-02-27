module Spree
  class Price < Spree.base_class
    include Spree::VatPriceCalculation
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    acts_as_paranoid

    MAXIMUM_AMOUNT = BigDecimal('99_999_999.99')

    belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant', inverse_of: :prices, touch: true

    before_validation :ensure_currency
    before_save :remove_compare_at_amount_if_equals_amount

    # legacy behavior
    validates :amount, allow_nil: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }, if: -> { Spree::Config.allow_empty_price_amount }

    # new behavior
    validates :amount, allow_nil: false, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }, unless: -> { Spree::Config.allow_empty_price_amount }

    validates :compare_at_amount, allow_nil: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }

    validates :currency, presence: true

    scope :with_currency, ->(currency) { where(currency: currency) }
    scope :non_zero, -> { where.not(amount: [nil, 0]) }
    scope :discounted, -> { where('compare_at_amount > amount') }
    scope :for_products, ->(products) { joins(variant: :product).where("#{Spree::Product.table_name}.id" => products) }

    extend DisplayMoney
    money_methods :amount, :price, :compare_at_amount
    alias display_compare_at_price display_compare_at_amount

    self.whitelisted_ransackable_attributes = ['amount', 'compare_at_amount']

    attribute :eligible_for_taxon_matching, :boolean, default: false
    before_validation -> { self.eligible_for_taxon_matching = new_record? ? discounted? : discounted? != was_discounted? }
    after_commit -> { variant&.product&.auto_match_taxons }, if: -> { eligible_for_taxon_matching? }

    def money
      Spree::Money.new(amount || 0, currency: currency.upcase)
    end

    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    def compare_at_money
      Spree::Money.new(compare_at_amount || 0, currency: currency)
    end

    def compare_at_amount=(compare_at_amount)
      self[:compare_at_amount] = Spree::LocalizedNumber.parse(compare_at_amount)
    end

    alias_attribute :price, :amount
    alias_method :price=, :amount=
    alias_attribute :compare_at_price, :compare_at_amount
    alias_method :compare_at_price=, :compare_at_amount=

    def price_including_vat_for(price_options)
      options = price_options.merge(tax_category: variant.tax_category)
      gross_amount(price, options)
    end

    def compare_at_price_including_vat_for(price_options)
      options = price_options.merge(tax_category: variant.tax_category)
      gross_amount(compare_at_price, options)
    end

    def display_price_including_vat_for(price_options)
      Spree::Money.new(price_including_vat_for(price_options), currency: currency)
    end

    def display_compare_at_price_including_vat_for(price_options)
      Spree::Money.new(compare_at_price_including_vat_for(price_options), currency: currency)
    end

    # returns the name of the price in a format of variant name and currency
    #
    # @return [String]
    def name
      "#{variant.name} - #{currency.upcase}"
    end

    # returns true if the price is discounted
    #
    # @return [Boolean]
    def discounted?
      compare_at_amount.to_i.positive? && compare_at_amount > amount
    end

    # returns true if the price was discounted
    #
    # @return [Boolean]
    def was_discounted?
      compare_at_amount_was.to_i.positive? && compare_at_amount_was > amount_was
    end

    # returns true if the price is zero
    #
    # @return [Boolean]
    def zero?
      amount.nil? || amount.zero?
    end

    # returns true if the price is not zero
    #
    # @return [Boolean]
    def non_zero?
      !zero?
    end

    private

    def ensure_currency
      self.currency ||= Spree::Store.default.default_currency
    end

    # removes the compare at amount if it is the same as the amount
    def remove_compare_at_amount_if_equals_amount
      self.compare_at_amount = nil if compare_at_amount == amount
    end
  end
end
