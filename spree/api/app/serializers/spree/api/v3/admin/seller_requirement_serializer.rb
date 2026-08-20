module Spree
  module Api
    module V3
      module Admin
        # A configured requirement, as the operator manages it. Admin-only:
        # what a marketplace asks of its sellers is between the operator and
        # the seller, and never appears on the store surface.
        class SellerRequirementSerializer < BaseSerializer
          typelize kind: :string, name: :string, description: [:string, nullable: true],
                   position: :number, active: :boolean, required: :boolean,
                   allow_multiple: :boolean, accepts_submissions: :boolean,
                   reviewed_by_operator: :boolean,
                   preferences: 'Record<string, unknown>',
                   custom_field_definition_ids: [:string, multi: true],
                   metadata: 'Record<string, unknown> | null'

          attributes :position, :active, :required, :metadata,
                     created_at: :iso8601,
                     updated_at: :iso8601

          # The kind, so a dashboard can key presentation off it without
          # parsing the Ruby class name.
          attribute :kind do |requirement|
            requirement.class.api_type
          end

          # What the seller sees — the operator's wording, or the kind's own.
          attribute :name do |requirement|
            requirement.display_name
          end

          attribute :description do |requirement|
            requirement.display_description
          end

          attribute :preferences do |requirement|
            requirement.serialized_preferences
          end

          # The definitions a requirement asks for, when its kind takes any.
          # Read through the association, so one the operator deleted is gone
          # rather than echoed back as an id nothing can address.
          attribute :custom_field_definition_ids do |requirement|
            if requirement.respond_to?(:custom_field_definition_prefixed_ids)
              requirement.custom_field_definition_prefixed_ids
            else
              []
            end
          end

          # Capabilities of the kind, so the operator's form knows whether to
          # offer a second row of it and whether sellers can submit anything.
          attribute :allow_multiple do |requirement|
            requirement.class.allow_multiple?
          end

          attribute :accepts_submissions do |requirement|
            requirement.class.accepts_submissions?
          end

          attribute :reviewed_by_operator do |requirement|
            requirement.class.reviewed_by_operator?
          end
        end
      end
    end
  end
end
