module Spree
  module Api
    module V3
      class ChannelSerializer < BaseSerializer
        typelize name: :string,
                 code: :string,
                 active: :boolean,
                 default: :boolean,
                 storefront_access: :string,
                 guest_checkout: :boolean

        attributes :name, :code, :active, :default

        # Resolved (channel → store fallback) values — what a client should act
        # on, as opposed to the raw nullable preferences on the admin serializer.
        attribute :storefront_access, &:resolved_storefront_access

        attribute :guest_checkout, &:resolved_guest_checkout
      end
    end
  end
end
