module Spree
  module Api
    module V3
      module Store
        module Orders
          # A buyer asking for an invoice on their order, and seeing whether
          # they already have.
          class InvoiceRequestsController < Store::ResourceController
            include Spree::Api::V3::Store::CustomerOrderParent

            request_params 'CreateInvoiceRequestParams', action: :create do |body|
              body.attribute :company_name, :string, nullable: true, example: 'Acme GmbH'
              body.attribute :tax_id, :string,
                             nullable: true, example: 'DE123456789',
                             description: 'The VAT or tax number to print on the invoice.'
              body.attribute :billing_address, :object,
                             nullable: true,
                             description: "Where the invoice is addressed, when not the order's billing address." do |address|
                address.include_attributes Spree::Api::V3::Store::AddressRequestSchema
              end
            end

            def create
              result = Spree.invoice_request_create_workflow.call(
                order: @parent,
                customer: try_spree_current_user,
                company_name: request_params[:company_name],
                tax_id: request_params[:tax_id],
                billing_address_params: request_params[:billing_address]
              )

              render_result(result, status: :created)
            end

            protected

            def model_class
              Spree::InvoiceRequest
            end

            def serializer_class
              Spree.api.invoice_request_serializer
            end

            def scope
              @parent.invoice_requests.order(created_at: :desc)
            end

            private

            def request_params
              @request_params ||= params.permit(*declared_permitted_attributes)
            end
          end
        end
      end
    end
  end
end
