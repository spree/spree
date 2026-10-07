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
            # an older copy is refused with 409, naming who saved last. `rebase`
            # marks the draft as based on Spree's current default.
            def update
              authorize! :update, Spree::EmailTemplate

              result = Spree.email_template_save_draft_workflow.call(
                store: current_store, key: email_template.key, locale: language, actor: current_actor,
                attributes: params.permit(:subject, :body, :lock_version, :rebase).to_h.symbolize_keys
              )
              render_email_template_result(result)
            end

            # DELETE /api/v3/admin/email_templates/:email_template_id/draft
            def destroy
              authorize! :update, Spree::EmailTemplate

              result = Spree.email_template_discard_draft_workflow.call(
                store: current_store, key: email_template.key, locale: language, lock_version: params[:lock_version].presence
              )
              render_email_template_result(result)
            end
          end
        end
      end
    end
  end
end
