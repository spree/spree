module Spree
  module Api
    module V3
      module Seller
        # One line of this seller's onboarding checklist.
        #
        # A value object, so no id of its own: the `id` is the requirement it
        # came from, which is what the panel posts a submission against.
        #
        # `blocking` is serialized rather than derived client-side so the
        # panel's "what is stopping me" list and the server's refusal on
        # submit-for-review cannot disagree. `kind` is what the panel keys
        # presentation off — which line gets a file picker, which gets a
        # checkbox, which just links away.
        #
        # Includes Alba directly instead of inheriting BaseSerializer, as the
        # operator's twin does: the base renders `id` by calling
        # `object.prefixed_id`, and this is a value object whose `id` is
        # already a prefixed id string. Inheriting would render `id: nil` and
        # cost the panel the one field it posts submissions against.
        class RequirementStatusSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize id: :string, kind: :string, name: :string,
                   description: [:string, nullable: true],
                   required: :boolean, position: :number, status: :string,
                   blocking: :boolean, action_url: [:string, nullable: true]

          attributes :id, :kind, :name, :description, :required, :position, :status, :action_url

          attribute :blocking do |status|
            status.blocking?
          end

          one :submission,
              resource: proc { Spree.api.seller_requirement_submission_serializer },
              if: proc { |status| status.submission.present? }
        end
      end
    end
  end
end
