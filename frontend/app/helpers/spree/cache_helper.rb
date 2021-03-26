module Spree
  module CacheHelper
    def http_cache_enabled?
      @http_cache_enabled ||= Spree::Frontend::Config[:http_cache_enabled]
    end
  end
end
