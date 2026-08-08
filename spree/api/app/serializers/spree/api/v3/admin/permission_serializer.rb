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

          typelize key: :string, resource: :string, kind: :string, group: :string,
                   group_label: :string, label: :string, description: :string

          attributes :key

          attribute(:resource) { |entry| entry.resource.name.to_s }
          attribute(:kind) { |entry| entry.kind.to_s }
          attribute(:group) { |entry| entry.resource.group.to_s }

          attribute(:group_label) do |entry|
            Spree.t("permissions_catalog.groups.#{entry.resource.group}",
                    default: entry.resource.group.to_s.humanize)
          end

          attribute(:label) do |entry|
            Spree.t("permissions_catalog.resources.#{entry.resource.name}.label",
                    default: entry.resource.name.to_s.humanize)
          end

          attribute(:description) do |entry|
            Spree.t("permissions_catalog.resources.#{entry.resource.name}.description", default: '')
          end
        end
      end
    end
  end
end
