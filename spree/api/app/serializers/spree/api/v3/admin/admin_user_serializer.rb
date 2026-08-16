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
                   avatar_url: [:string, nullable: true],
                   roles: 'Array<{ id: string; name: string }>',
                   stores: 'Array<{ id: string; name: string; code: string }>'

          attributes :email, :first_name, :last_name, :full_name, :selected_locale,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :avatar_url do |user|
            image_url_for(user.avatar)
          end

          # Roles assigned to this user *for the current store*. Each store
          # gets its own role set via `Spree::RoleUser`, so this attribute is
          # scoped against `current_store` rather than returning every role
          # the user might have on other stores. Block receives `params`
          # only when Alba passes it through the `serializer_params` hash —
          # we fall back to `Spree::Current.store` if not.
          # Filtered in Ruby rather than with `for_resource`, so the staff
          # index's preloaded roles are used instead of a query per user.
          attribute :roles do |user, params|
            store = params&.dig(:store) || Spree::Current.store
            roles = user.spree_roles.to_a
            roles = roles.select { |role| role.resource == store } if store
            roles.map { |role| { id: role.prefixed_id, name: role.name } }
          end

          # Every store this user holds a role on — unlike `roles`,
          # deliberately NOT scoped to the current store, so the dashboard
          # store switcher can offer all accessible stores. Read off the same
          # preloaded roles, and deduped/sorted in Ruby, so the staff index
          # spends no extra query per user.
          attribute :stores do |user|
            stores = user.spree_roles.filter_map { |role| role.resource if role.resource.is_a?(Spree::Store) }

            stores.uniq.sort_by(&:name).map do |store|
              { id: store.prefixed_id, name: store.name, code: store.code }
            end
          end
        end
      end
    end
  end
end
