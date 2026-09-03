module Spree
  module Api
    module V3
      module Seller
        # A destination a seller can narrow their own method to.
        #
        # Declared rather than subclassed, like every serializer on this
        # branch. No members: the picker names the zone the marketplace drew,
        # and which countries and postal ranges make it up is the
        # marketplace's own configuration.
        class DeliveryZoneSerializer < BaseSerializer
          typelize name: :string, description: [:string, nullable: true],
                   delivery_profile_id: :string

          attributes :name, :description

          # What the panel filters the picker by, so a zone is only offered
          # under the profile it belongs to.
          attribute :delivery_profile_id do |record|
            record.delivery_profile&.prefixed_id
          end
        end
      end
    end
  end
end
