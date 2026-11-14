module Spree
  module Stores
    # @deprecated Removed in Spree 6.2. Move a store to another country with
    #   {Spree::Store#relocate} and deploy its defaults with `spree seed defaults`.
    class ProvisionDefaults < Spree::Seeds::RemovedStoreDefaults
      private

      def replacement
        'Move the store with Spree::Store#relocate and deploy its defaults with `spree seed defaults`.'
      end
    end
  end
end
