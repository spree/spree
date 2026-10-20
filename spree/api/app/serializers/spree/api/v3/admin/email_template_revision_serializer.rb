module Spree
  module Api
    module V3
      module Admin
        class EmailTemplateRevisionSerializer < V3::BaseSerializer
          typelize subject: [:string, nullable: true],
                   body: :string,
                   published_by_id: [:string, nullable: true],
                   published_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind']

          attributes :subject, :body, created_at: :iso8601

          actor_attributes :published_by
        end
      end
    end
  end
end
