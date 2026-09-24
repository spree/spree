module Spree
  module Api
    module V3
      module Admin
        # Whoever performed an action — an admin user, an API key, or a class
        # an extension registered in `Spree.actor_classes`.
        #
        # One shape for every kind, so a client renders "cancelled by" the same
        # way whether a person clicked the button or a warehouse connector
        # called the endpoint. See docs/plans/6.0-action-actors.md.
        class ActorSerializer < V3::BaseSerializer
          typelize type: [:string, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   label: [:string, nullable: true]

          # `admin_user` / `api_key`, never the Ruby class name.
          attribute :type do |actor|
            actor.actor_kind
          end

          # What a timeline shows: a person's name or email, a key's name.
          attribute :label do |actor|
            actor.actor_label
          end
        end
      end
    end
  end
end
