module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          class PreviewsController < Admin::BaseController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            before_action :authorize_sample_data!

            # POST /api/v3/admin/email_templates/:email_template_id/preview
            #
            # Renders the template with sample data built from the store's latest
            # matching record, or the one `record_id` names. An unsaved `subject`
            # and `body` take the place of the current version. Returns the
            # rendered email and the variables it was rendered with.
            def create
              authorize! :update, Spree::EmailTemplate

              preview = build_preview
              preview.call

              render json: Spree.api.admin_email_template_preview_serializer.new(preview, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end
