# frozen_string_literal: true

module Spree
  module Events
    class InvitationSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          email: resource.email,
          status: resource.status.to_s,
          resource_type: resource.resource_type,
          resource_id: resource.resource_id,
          inviter_type: resource.inviter_type,
          inviter_id: resource.inviter_id,
          invitee_type: resource.invitee_type,
          invitee_id: resource.invitee_id,
          role_id: resource.role_id,
          expires_at: timestamp(resource.expires_at),
          accepted_at: timestamp(resource.accepted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
