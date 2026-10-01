module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          class RestorationsController < Admin::BaseController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            # POST /api/v3/admin/email_templates/:email_template_id/revisions/:revision_id/restoration
            #
            # Copies the revision into the draft, to be published like any change.
            def create
              authorize! :update, Spree::EmailTemplate

              revision = email_template_revisions.find_by_prefix_id!(params[:revision_id])

              result = Spree.email_template_restore_revision_workflow.call(
                revision: revision, actor: current_actor, lock_version: params[:lock_version]
              )
              render_email_template_result(result, status: :created)
            end
          end
        end
      end
    end
  end
end
