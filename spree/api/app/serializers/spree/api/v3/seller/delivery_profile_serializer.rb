module Spree
  module Api
    module V3
      module Seller
        # A delivery profile as a seller picks it: a name, and whether it is
        # the one a product lands on when they pick none.
        #
        # Declared rather than subclassed from the admin serializer, like every
        # serializer on this branch: which warehouses and methods sit behind a
        # profile is the marketplace's configuration, not a seller's to read.
        class DeliveryProfileSerializer < BaseSerializer
          typelize name: :string, default: :boolean, digital: :boolean

          attributes :name, :default

          # Whether this profile's goods are delivered digitally. A seller's
          # own method ships by hand, so a digital profile can carry a product
          # but never one of their methods — the method form filters its
          # picker on this rather than letting the save fail on a provider
          # field the seller cannot see.
          attribute :digital, &:digital?
        end
      end
    end
  end
end
