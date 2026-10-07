module Spree
  module Api
    module V3
      module Admin
        class EmailTemplateDraftSerializer < V3::BaseSerializer
          typelize subject: [:string, nullable: true],
                   body: :string,
                   lock_version: :number,
                   updated_by_id: [:string, nullable: true],
                   updated_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind']

          attributes :subject, :body, :lock_version, created_at: :iso8601, updated_at: :iso8601

          actor_attributes :updated_by
        end
      end
    end
  end
end
