module Spree
  module Seeds
    # The services that created a store's defaults from Ruby before Spree 6.1.
    # The defaults are now deployed through the Admin API, so these only warn;
    # they keep the old names loadable for one release.
    #
    # @deprecated Removed in Spree 6.2. Deploy the store defaults with
    #   `spree seed defaults` instead.
    class RemovedStoreDefaults
      prepend Spree::ServiceModule::Base

      def call(**)
        Spree::Deprecation.warn("#{self.class.name} is deprecated, does nothing since Spree 6.1 and will be removed in Spree 6.2. #{replacement}")
        success(nil)
      end

      private

      def replacement
        'Store defaults are deployed through the Admin API: run `spree seed defaults`.'
      end
    end
  end
end
