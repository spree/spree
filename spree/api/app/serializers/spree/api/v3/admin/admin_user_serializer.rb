module Spree
  module Api
    module V3
      module Admin
        class AdminUserSerializer < V3::BaseSerializer
          typelize email: :string,
                   first_name: [:string, nullable: true],
                   last_name: [:string, nullable: true],
                   full_name: [:string, nullable: true],
                   selected_locale: [:string, nullable: true],
                   roles: 'Array<{ id: string; name: string }>'

          attributes :email, :first_name, :last_name, :full_name, :selected_locale,
                     created_at: :iso8601, updated_at: :iso8601

          # Roles assigned to this user *for the current store*. Each store
          # gets its own role set via `Spree::RoleUser`, so this attribute is
          # scoped against `current_store` rather than returning every role
          # the user might have on other stores. Block receives `params`
          # only when Alba passes it through the `serializer_params` hash —
          # we fall back to `Spree::Current.store` if not.
          attribute :roles do |user, params|
            store = params&.dig(:store) || Spree::Current.store
            scope = user.role_users
            scope = scope.where(resource: store) if store
            scope.includes(:role).map { |ru| { id: ru.role.prefixed_id, name: ru.role.name } }
          end
        end
      end
    end
  end
end
