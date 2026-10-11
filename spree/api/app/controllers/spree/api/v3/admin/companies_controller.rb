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

          request_params 'CompanyParams' do |body|
            body.external_references
            body.attribute :name, :string, example: 'Globex Corporation', description: 'Required when creating.'
            body.attribute :kind, :string,
              choices: Spree::Company::KINDS,
              example: 'company',
              description: '`company` is a legal entity (may hold tax registrations), `division` an organizational unit. Roots must be `company`.'
            body.attribute :parent_id, :id,
              nullable: true,
              example: 'comp_86Rf07xd4z',
              description: 'The parent node. Omit or null for a root.'
            body.attribute :po_number_required, :boolean,
              description: "Whether this buyer's own procurement process demands a PO reference on every order: checkout asks for one and refuses to complete without it."
            body.attribute :metadata, :hash
          end

          protected

          def model_class
            Spree::Company
          end

          def serializer_class
            Spree.api.admin_company_serializer
          end

          def collection_includes
            [:children, :memberships, :external_references]
          end

          def permitted_params
            resolve_parent_param(params.permit(*permitted_attributes))
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
