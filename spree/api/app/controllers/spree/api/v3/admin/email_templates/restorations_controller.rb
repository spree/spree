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

              revision = Spree::EmailTemplateRevision.where(
                email_template: current_store.email_templates.for_key(email_template.key, language)
              ).find_by_prefix_id!(params[:revision_id])

              result = Spree.email_template_restore_revision_workflow.call(
                revision: revision, actor: current_actor, lock_version: params[:lock_version]
              )
              return render_stale_draft if result.error&.value == :stale
              return render_result_error(result) unless result.success?

              render json: serialize_email_template(reload: true), status: :created
            end
          end
        end
      end
    end
  end
end
