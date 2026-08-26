module Spree
  module Api
    module V3
      # The company node as members and event subscribers see it: the
      # storefront self-service surface renders it directly, lifecycle events
      # use it as their payload, and the admin serializer extends it so
      # back-office fields stay in one place.
      class CompanySerializer < BaseSerializer
        typelize name: :string,
                 kind: :string, parent_id: [:string, nullable: true],
                 ancestors: 'Array<{id: string, name: string, kind: string}>'

        attributes :name, :kind

        attribute :parent_id do |company|
          company.parent&.prefixed_id
        end

        # The path above this node, root first — lets a client render
        # "Acme / EMEA / Berlin" without a request per level. Bounded by the
        # tree's depth cap.
        attribute :ancestors do |company|
          company.ancestors.reverse.map do |node|
            { 'id' => node.prefixed_id, 'name' => node.name, 'kind' => node.kind }
          end
        end
      end
    end
  end
end
