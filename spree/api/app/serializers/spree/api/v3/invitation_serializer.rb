# frozen_string_literal: true

module Spree
  module Api
    module V3
      class InvitationSerializer < BaseSerializer
        typelize email: :string, status: :string,
                 resource_type: [:string, nullable: true], resource_id: [:string, nullable: true],
                 inviter_type: [:string, nullable: true], inviter_id: [:string, nullable: true],
                 invitee_type: [:string, nullable: true], invitee_id: [:string, nullable: true],
                 role_id: [:string, nullable: true],
                 expires_at: [:string, nullable: true], accepted_at: [:string, nullable: true]

        attributes :email, :resource_type, :inviter_type, :invitee_type,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :status do |invitation|
          invitation.status.to_s
        end

        attribute :resource_id do |invitation|
          invitation.resource&.prefixed_id
        end

        attribute :inviter_id do |invitation|
          invitation.inviter&.prefixed_id
        end

        attribute :invitee_id do |invitation|
          invitation.invitee&.prefixed_id
        end

        attribute :role_id do |invitation|
          invitation.role&.prefixed_id
        end

        attribute :expires_at do |invitation|
          invitation.expires_at&.iso8601
        end

        attribute :accepted_at do |invitation|
          invitation.accepted_at&.iso8601
        end
      end
    end
  end
end
