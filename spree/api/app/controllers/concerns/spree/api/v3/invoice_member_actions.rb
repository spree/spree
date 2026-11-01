module Spree
  module Api
    module V3
      # One invoice, wherever it was listed from: downloading it and sending
      # it to its recipient again. Shared by the operator's and the seller's
      # top-level invoices controllers, which fetch and authorize `@resource`
      # through their own scope first.
      module InvoiceMemberActions
        extend ActiveSupport::Concern

        included do
          include Spree::Api::V3::StreamsPrivateFile

          before_action :set_resource, only: [:show, :destroy, :download, :resend]
        end

        # GET .../invoices/:id/download — streamed, so the credentials that
        # reached the action are what protect the file.
        def download
          stream_private_file(@resource.file)
        end

        # POST .../invoices/:id/resend — emails the invoice to its recipient
        # again, whatever the store's automatic invoice email setting says.
        def resend
          @resource.publish_event('invoice.delivery_requested')
          render json: serialize_resource(@resource), status: :accepted
        end

        protected

        def model_class
          Spree::Invoice
        end

        def read_actions
          %w[index show download]
        end

        def collection_includes
          [:issuer, :order, { file_attachment: :blob }]
        end

        # Downloading is reading; resending is acting on the invoice, which
        # changes nothing about it but sends mail in the store's name.
        def authorize_resource!(resource = @resource, action = action_name.to_sym)
          mapped = case action
                   when :download then :show
                   when :resend then :update
                   else action
                   end

          authorize!(mapped, resource)
        end
      end
    end
  end
end
