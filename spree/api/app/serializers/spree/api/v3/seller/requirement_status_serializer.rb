module Spree
  module Api
    module V3
      module Seller
        class RequirementStatusSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize id: :string, kind: :string, name: :string,
                   description: [:string, nullable: true],
                   required: :boolean, position: :number, status: :string,
                   blocking: :boolean, action_url: [:string, nullable: true],
                   accepts_submissions: :boolean, requires_file: :boolean,
                   accepted_content_types: [:string, multi: true],
                   required_policies: 'Array<{ name: string; published: boolean }>'

          attributes :id, :kind, :name, :description, :required, :position, :status, :action_url

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

          # Which documents this line asks for and which the seller has
          # published — so the panel names what is still owed rather than
          # saying the requirement is unmet. Empty for every other kind.
          attribute :required_policies, if: proc { |status| status.required_policies.any? } do |status|
            status.required_policies
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
