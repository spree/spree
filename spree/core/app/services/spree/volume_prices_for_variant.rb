module Spree
  # Resolves quantity-based price tiers for a variant, one entry per VolumeRule
  # price list that applies at the rule's minimum quantity, matching checkout pricing.
  class VolumePricesForVariant
    VolumePrice = Data.define(:name, :min_quantity, :max_quantity, :price)

    # @param variant [Spree::Variant]
    # @param user [Spree.user_class, nil]
    # @return [Array<VolumePrice>]
    def self.call(variant:, user: nil)
      new(variant: variant, user: user).call
    end

    def initialize(variant:, user: nil)
      @variant = variant
      @user = user
      @currency = Spree::Current.currency&.upcase
    end

    # @return [Array<VolumePrice>]
    def call
      Spree::Pricing.price_lists_for(pricing_context).filter_map { |list| tier_for(list) }.sort_by(&:min_quantity)
    end

    private

    attr_reader :variant, :user, :currency

    def pricing_context
      @pricing_context ||= Spree::Pricing::Context.new(currency: currency)
    end

    def tier_context(quantity)
      Spree::Pricing::Context.new(variant: variant, currency: currency, user: user, quantity: quantity)
    end

    def tier_for(list)
      volume_rule = list.price_rules.find { |rule| rule.is_a?(Spree::PriceRules::VolumeRule) }
      return unless volume_rule

      return unless list.applicable?(tier_context(volume_rule.preferred_min_quantity))

      price = price_on_list(list)
      return if price.blank? || price.amount.blank?

      VolumePrice.new(
        name: list.name,
        min_quantity: volume_rule.preferred_min_quantity,
        max_quantity: volume_rule.preferred_max_quantity,
        price: price
      )
    end

    def price_on_list(list)
      if variant.prices.loaded?
        loaded = variant.prices.detect do |price|
          price.currency == currency && price.price_list_id == list.id && price.amount.present? && !price.amount.zero?
        end
        return loaded if loaded.present?
      end

      variant.prices.with_currency(currency).where(price_list_id: list.id).non_zero.first
    end
  end
end
