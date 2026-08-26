module Spree
  module Api
    module V3
      module Admin
        # Company nodes — tree-aware CRUD. A company is a customer record, so
        # it answers to the customer scopes rather than earning one of its own.
        #
        # The tree is driven by Ransack: `?q[parent_id_null]=1` lists roots,
        # `?q[parent_id_eq]=` a node's children. Deleting a node destroys its
        # subtree. Re-parenting is an ordinary update — the model revalidates
        # depth, cycle and store.
        class CompaniesController < ResourceController
          scoped_resource :customers

          protected

          def model_class
            Spree::Company
          end

          def serializer_class
            Spree.api.admin_company_serializer
          end

          def scope
            super.for_store(current_store)
          end

          def collection_includes
            [:children, :memberships, :external_references]
          end

          def permitted_params
            permitted = params.permit(*model_additional_permitted_attributes,
                                      :name, :kind, :parent_id, metadata: {})
            resolve_parent_param(permitted)
          end

          private

          # The parent is an incidental lookup like any other: resolved through
          # the store so another tenant's node 404s rather than becoming this
          # node's parent.
          def resolve_parent_param(permitted)
            return permitted unless permitted.key?(:parent_id)

            permitted[:parent_id] =
              if permitted[:parent_id].present?
                current_store.companies.find_by_prefix_id!(permitted[:parent_id]).id
              else
                nil
              end
            permitted
          end
        end
      end
    end
  end
end
