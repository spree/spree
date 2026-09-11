module Spree
  module Api
    module V3
      module Seller
        class RequirementStatusSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize id: :string, kind: [:string, comment: 'Requirement kind. Built-in: accept_terms, complete_profile, billing_address, returns_address, delivery_method, package_type, minimum_products, payout_account, required_custom_fields, policy, attestation, operator_review, document. Extensions may register more.'], name: :string,
                   description: [:string, nullable: true],
                   required: :boolean, position: :number, status: [:string, enum: Spree::SellerRequirementStatus::STATUSES],
                   blocking: :boolean, action_url: [:string, nullable: true],
                   blocker: ['{ state: string; message: string | null } | null'],
                   accepts_submissions: :boolean, requires_file: :boolean,
                   accepted_content_types: [:string, multi: true],
                   required_policy_name: [:string, nullable: true]

          attributes :id, :kind, :name, :description, :required, :position, :status, :action_url, :blocker

          attribute :blocking do |status|
            status.blocking?
          end

          attribute :accepts_submissions do |status|
            status.requirement.class.accepts_submissions?
          end

          attribute :requires_file do |status|
            status.requirement.class.requires_file?
          end

          attribute :accepted_content_types do |status|
            status.requirement.accepted_content_types
          end

          # The document this line asks for, so the panel can offer to create
          # exactly that policy. Null for every other kind.
          attribute :required_policy_name do |status|
            status.required_policy_name
          end

          one :submission,
              resource: proc { Spree.api.seller_requirement_submission_serializer },
              if: proc { |status| status.submission.present? }

          many :custom_fields,
               resource: proc { Spree.api.seller_requirement_custom_field_serializer },
               if: proc { |status| status.custom_fields.any? } do |status|
            status.custom_fields
          end
        end
      end
    end
  end
end
