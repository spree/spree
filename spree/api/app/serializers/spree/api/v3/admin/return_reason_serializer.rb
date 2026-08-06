module Spree
  module Api
    module V3
      module Admin
        # Admin-only: reasons are back-office vocabulary and have no Store API
        # controller, so there is no store serializer to extend.
        #
        # The three reason serializers are deliberately parallel rather than
        # sharing a base class: Typelizer emits one TS type per serializer, so
        # a shared parent would publish an abstract `Reason` type into the
        # admin SDK that no endpoint returns.
        class ReturnReasonSerializer < V3::BaseSerializer
          typelize name: :string, active: :boolean, can_be_deleted: :boolean

          attributes :name, :active,
                     created_at: :iso8601, updated_at: :iso8601

          # Lets the dashboard hide destructive controls instead of offering a
          # delete that the model will refuse.
          attribute :can_be_deleted do |reason|
            reason.can_be_deleted?
          end
        end
      end
    end
  end
end
