module Spree
  module Seeds
    # Seeds the gated Wholesale channel every store ships with by default —
    # the reference "blended DTC + B2B" setup: the default channel stays
    # public while wholesale requires login and forbids guest checkout.
    # See docs/plans/5.6-store-channel-context-and-key-binding.md.
    class Channels
      prepend Spree::ServiceModule::Base

      WHOLESALE_CODE = 'wholesale'.freeze

      def call
        Spree::Store.find_each do |store|
          store.ensure_default_channel

          store.channels.find_or_create_by!(code: WHOLESALE_CODE) do |channel|
            channel.name = 'Wholesale'
            channel.preferred_storefront_access = 'login_required'
            channel.preferred_guest_checkout = false
          end
        end
      end
    end
  end
end
