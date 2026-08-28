module Spree
  module Api
    module V3
      module Admin
        # One line of a seller's onboarding checklist — a requirement
        # evaluated against them. A value object, so no id of its own: the
        # `id` here is the requirement it came from, which is what a caller
        # acts on.
        class SellerRequirementStatusSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize id: :string, kind: :string, name: :string,
                   description: [:string, nullable: true],
                   required: :boolean, position: :number, status: :string,
                   blocking: :boolean, action_url: [:string, nullable: true],
                   required_policy_name: [:string, nullable: true]

          attributes :id, :kind, :name, :description, :required, :position, :status, :action_url

          # Whether this stands between the seller and approval. Serialized
          # rather than left to each client to derive, so the dashboard's
          # override warning and the approval gate cannot disagree.
          attribute :blocking do |status|
            status.blocking?
          end

          # The document this line asks for, and what the seller published
          # against it. Embedded rather than left to a second request: the
          # operator is deciding whether to approve, and a line that says
          # "Done" without showing the text is not something to approve on.
          attribute :required_policy_name do |status|
            status.required_policy_name
          end

          one :submission,
              resource: proc { Spree.api.admin_seller_requirement_submission_serializer },
              if: proc { |status| status.submission.present? }

          one :published_policy,
              resource: proc { Spree.api.admin_policy_serializer },
              if: proc { |status| status.published_policy.present? }
        end
      end
    end
  end
end
