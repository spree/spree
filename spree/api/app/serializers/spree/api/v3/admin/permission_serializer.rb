module Spree
  module Api
    module V3
      module Admin
        # Serializes one permission catalog entry
        # (Spree::PermissionConfiguration::Entry) for the discovery endpoint.
        # Labels and descriptions resolve through Spree.t so backend extensions
        # localize without shipping dashboard translations.
        class PermissionSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize key: :string, resource: :string, kind: [:string, enum: %w[read write]], group: :string,
                   group_label: :string, label: :string, description: :string

          attributes :key

          attribute(:resource) { |entry| entry.scope.name.to_s }
          attribute(:kind) { |entry| entry.kind.to_s }
          attribute(:group) { |entry| entry.scope.group.to_s }

          attribute(:group_label) do |entry|
            Spree.t("permissions_catalog.groups.#{entry.scope.group}",
                    default: entry.scope.group.to_s.humanize)
          end

          attribute(:label) do |entry|
            Spree.t("permissions_catalog.resources.#{entry.scope.name}.label",
                    default: entry.scope.name.to_s.humanize)
          end

          attribute(:description) do |entry|
            Spree.t("permissions_catalog.resources.#{entry.scope.name}.description", default: '')
          end
        end
      end
    end
  end
end
