module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          class PublicationsController < Admin::BaseController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            before_action :authorize_sample_data!

            # POST /api/v3/admin/email_templates/:email_template_id/publication
            #
            # Makes the draft live. A draft that does not render with sample data
            # (for the layout or a partial: in any email using it) is refused with
            # 422 and each problem's email and line.
            def create
              authorize! :update, Spree::EmailTemplate

              result = Spree.email_template_publish_workflow.call(
                store: current_store, key: email_template.key, locale: language, actor: current_actor,
                lock_version: params[:lock_version].presence
              )
              render_email_template_result(result, status: :created)
            end
          end
        end
      end
    end
  end
end
