module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::Role}. A role belongs to the store
        # it governs; permissions are flat catalog keys (see the
        # `/admin/permissions` discovery endpoint). `mutable: false` marks the
        # protected admin role and host-locked rows — the dashboard renders
        # those read-only.
        class RoleSerializer < V3::BaseSerializer
          typelize name: :string, description: 'string | null', mutable: :boolean,
                   users_count: :number
          typelize permissions: [:string, multi: true]

          attributes :name, :description, created_at: :iso8601, updated_at: :iso8601

          # The admin role ignores its stored list and grants everything — so
          # it reports every key its own audience may hold, which is what the
          # role grid renders and what a duplicate of it copies.
          attribute(:permissions) do |role|
            role.name == Spree::Role::ADMIN_ROLE ? Spree.permissions.grantable_keys(role.audience) : role.permissions
          end

          attribute(:mutable, &:mutable?)

          # Staff assignments. The role belongs to one store already, so every
          # assignment it has is on that store.
          attribute :users_count do |role|
            role.role_users.size
          end
        end
      end
    end
  end
end
