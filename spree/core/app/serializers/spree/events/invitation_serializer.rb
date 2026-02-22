# frozen_string_literal: true

module Spree
  module Events
    class InvitationSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          email: resource.email,
          status: resource.status.to_s,
          resource_type: resource.resource_type,
          resource_id: public_id(resource.resource),
          inviter_type: resource.inviter_type,
          inviter_id: public_id(resource.inviter),
          invitee_type: resource.invitee_type,
          invitee_id: public_id(resource.invitee),
          role_id: public_id(resource.role),
          expires_at: timestamp(resource.expires_at),
          accepted_at: timestamp(resource.accepted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
