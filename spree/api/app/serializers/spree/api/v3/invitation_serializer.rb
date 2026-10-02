# frozen_string_literal: true

module Spree
  module Api
    module V3
      class InvitationSerializer < BaseSerializer
        typelize email: :string, status: [:string, enum: Spree::Invitation.statuses, enum_type_name: 'InvitationStatus'],
                 resource_type: [:string, nullable: true], resource_id: [:string, nullable: true],
                 inviter_type: [:string, nullable: true], inviter_id: [:string, nullable: true],
                 invitee_type: [:string, nullable: true], invitee_id: [:string, nullable: true],
                 role_id: [:string, nullable: true],
                 expires_at: [:string, nullable: true], accepted_at: [:string, nullable: true]

        attributes :email,
                   created_at: :iso8601, updated_at: :iso8601

        string_attributes :status

        # `"store"` / `"admin_user"`, not the polymorphic class names.
        attribute :resource_type do |invitation|
          Spree::Base.polymorphic_api_type(invitation.resource_type)
        end

        attribute :inviter_type do |invitation|
          Spree::Base.polymorphic_api_type(invitation.inviter_type)
        end

        attribute :invitee_type do |invitation|
          Spree::Base.polymorphic_api_type(invitation.invitee_type)
        end

        prefixed_id_attributes :resource, :inviter, :invitee, :role

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
