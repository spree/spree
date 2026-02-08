# frozen_string_literal: true

module Spree
  module Events
    class InvitationSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          email: resource.email,
          status: resource.status.to_s,
          resource_type: resource.resource_type,
          resource_id: association_prefix_id(:resource),
          inviter_type: resource.inviter_type,
          inviter_id: association_prefix_id(:inviter),
          invitee_type: resource.invitee_type,
          invitee_id: association_prefix_id(:invitee),
          role_id: association_prefix_id(:role),
          expires_at: timestamp(resource.expires_at),
          accepted_at: timestamp(resource.accepted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
