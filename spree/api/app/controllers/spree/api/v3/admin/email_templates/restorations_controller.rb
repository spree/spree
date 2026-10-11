module Spree
  module Api
    module V3
      module Admin
        module EmailTemplates
          class RestorationsController < Admin::BaseController
            include Spree::Api::V3::Admin::EmailTemplateLookup

            request_params 'EmailTemplateRestoreParams' do |body|
              body.include_attributes Spree::Api::V3::Admin::EmailTemplateLanguageRequestSchema
              body.attribute :lock_version, :integer,
                nullable: true,
                permit: false,
                description: "The open draft's `lock_version`, or null when there is none; checked as when saving."
            end

            # POST /api/v3/admin/email_templates/:email_template_id/revisions/:revision_id/restoration
            #
            # Copies the revision into the language's draft, to be published
            # like any change. A language without a version of its own can
            # restore one of the version for every language its customers get.
            def create
              authorize! :update, Spree::EmailTemplate

              revision = Spree::EmailTemplateRevision.where(
                email_template: current_store.email_templates.where(
                  key: email_template.key, locale: [language, Spree::EmailTemplate::ANY_LOCALE]
                )
              ).find_by_prefix_id!(params[:revision_id])

              result = Spree.email_template_restore_revision_workflow.call(
                revision: revision, actor: current_actor, locale: language,
                draft_version: params.key?(:lock_version) ? { lock_version: params[:lock_version] } : {}
              )
              render_email_template_result(result, status: :created)
            end
          end
        end
      end
    end
  end
end
