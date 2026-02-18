module Spree
  module Store::MultiStoreOverrides
    def url_or_custom_domain
      default_custom_domain&.url || url
    end

    def formatted_url_or_custom_domain
      formatted_custom_domain || formatted_url
    end
  end
end
