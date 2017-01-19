# Methods added to this helper will be available to all templates in the frontend.
module Spree
  module StoreHelper
    def cache_key_for_taxons
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        cache_key_for_taxons is deprecated. Rails >= 5 has built-in support for collection cache keys.
        Instead in your view use:
        cache [I18n.locale, @taxons] do
      EOS
      max_updated_at = @taxons.maximum(:updated_at).to_i
      parts = [@taxon.try(:id), max_updated_at].compact.join("-")
      "#{I18n.locale}/taxons/#{parts}"
    end
  end
end
