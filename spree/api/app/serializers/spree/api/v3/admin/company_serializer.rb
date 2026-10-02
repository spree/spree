module Spree
  module Api
    module V3
      module Admin
        class CompanySerializer < V3::CompanySerializer
          include Concerns::ExternalReferencesAttribute

          typelize children_count: :number, members_count: :number,
                   metadata: 'Record<string, unknown> | null'

          attributes :metadata, created_at: :iso8601, updated_at: :iso8601

          # Saves the dashboard a request per row just to render the tree
          # expander and "3 members".
          attribute :children_count do |company|
            company.children.size
          end

          # The member count covers the node's whole subtree
          attributes :members_count

          many :children,
               resource: proc { Spree.api.admin_company_serializer },
               if: proc { expand?('children') }

          many :addresses,
               resource: proc { Spree.api.admin_address_serializer },
               if: proc { expand?('addresses') }

          many :memberships,
               resource: proc { Spree.api.admin_company_membership_serializer },
               if: proc { expand?('memberships') }
        end
      end
    end
  end
end
