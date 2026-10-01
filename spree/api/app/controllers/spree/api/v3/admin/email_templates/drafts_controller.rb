module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          # The draft of an editable email template: saved in any state, while
          # customers keep receiving the published version.
          class DraftsController < Admin::BaseController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            # PUT /api/v3/admin/email_templates/:email_template_id/draft
            #
            # Send the `lock_version` the draft was loaded with: a save made from
            # an older copy is refused with 409, naming who saved last.
            def update
              authorize! :update, Spree::EmailTemplate

              result = Spree.email_template_save_draft_workflow.call(
                store: current_store, key: email_template.key, locale: language, actor: current_actor,
                attributes: params.permit(:subject, :body, :lock_version).to_h.symbolize_keys
              )
              return render_stale_draft if result.error&.value == :stale
              return render_result_error(result) unless result.success?

              render json: serialize_email_template(reload: true)
            end

            # DELETE /api/v3/admin/email_templates/:email_template_id/draft
            def destroy
              authorize! :update, Spree::EmailTemplate

              current_store.email_template_drafts.for_key(email_template.key, language).destroy_all
              render json: serialize_email_template(reload: true)
            end
          end
        end
      end
    end
  end
end
