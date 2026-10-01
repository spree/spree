module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          class TestEmailsController < Admin::BaseController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            before_action :authorize_sample_data!

            # POST /api/v3/admin/email_templates/:email_template_id/test_email
            #
            # Sends the template, rendered as the preview renders it, to the
            # signed-in admin. Never to another address: the sample data comes
            # from a real customer's records.
            def create
              authorize! :update, Spree::EmailTemplate
              return render_no_recipient unless current_user

              build_preview.call
              Spree::EmailTemplateMailer.test_email(current_store, current_user.email, email_template.key, **preview_arguments).deliver_later

              render json: { sent_to: current_user.email }, status: :accepted
            end

            private

            def render_no_recipient
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:invalid_request],
                message: Spree.t('email_templates.test_email_needs_admin'),
                status: :unprocessable_content
              )
            end
          end
        end
      end
    end
  end
end
