module Spree
  module Emails
    class InvitationSerializer < BaseSerializer
      attributes :email

      attribute :resource_name do |invitation|
        invitation.resource.try(:name)
      end

      attribute :inviter_name do |invitation|
        invitation.inviter.try(:full_name).presence || invitation.inviter.try(:name)
      end

      attribute :inviter_first_name do |invitation|
        invitation.inviter.try(:first_name)
      end

      # Nil until the invitation is accepted by someone with an account.
      attribute :invitee_name do |invitation|
        invitation.invitee.try(:full_name).presence || invitation.invitee.try(:name)
      end

      attribute :invitee_first_name do |invitation|
        invitation.invitee.try(:first_name)
      end
    end
  end
end
