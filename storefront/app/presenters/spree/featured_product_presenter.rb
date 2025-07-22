module Spree
  class FeaturedProductPresenter
    def initialize(section, params:, currency:)
      @section = section
      @params = params
      @currency = currency

      initialize_selected_variants if product
    end

    attr_reader :selected_variant, :variant_from_options

    delegate :product, to: :section

    private

    attr_reader :section, :params, :currency, :store

    def initialize_selected_variants
      options_hash = if params.present?
                       params.split(',').to_h do |option|
                         key, *value = option.split(':')
                         [key, value.join(':')]
                       end
                     else
                       {}
                     end

      variant_finder = Spree::Storefront::VariantFinder.new(
        product: product,
        variant_id: nil,
        options_hash: options_hash,
        current_currency: currency
      )

      @selected_variant, @variant_from_options =
        Rails.cache.fetch([product.cache_key_with_version, 'variant-finder', currency, options_hash].compact) do
          variant_finder.find
        end
    end
  end
end
