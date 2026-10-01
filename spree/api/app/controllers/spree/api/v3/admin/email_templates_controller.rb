module Spree
  module Api
    module V3
      module Admin
        # The customer email templates, layout and shared partials merchants
        # may edit, addressed by their key with dots
        # (`spree.order_mailer.confirm_email`). `language` picks the version:
        # a language code, or `any` (the default) for every language.
        class EmailTemplatesController < Admin::BaseController
          include Spree::Api::V3::Admin::EmailTemplateLookup

          skip_before_action :load_email_template, only: :index

          # GET /api/v3/admin/email_templates
          def index
            authorize! :read, Spree::EmailTemplate

            entries = Spree::EmailTemplates::Entry.all(current_store, locale: language)
            render json: { data: serialize_collection(entries), meta: {} }
          end

          # GET /api/v3/admin/email_templates/:id
          def show
            authorize! :read, Spree::EmailTemplate

            render json: serialize_email_template
          end

          # DELETE /api/v3/admin/email_templates/:id
          #
          # Goes back to Spree's default for this language. The store's version
          # and its history are kept, so a revision can still be restored.
          def destroy
            authorize! :update, Spree::EmailTemplate

            result = Spree.email_template_revert_workflow.call(
              store: current_store, key: email_template.key, locale: language, actor: current_actor
            )
            return render_result_error(result) unless result.success?

            render json: serialize_email_template(reload: true)
          end
        end
      end
    end
  end
end
