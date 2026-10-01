module Spree
  module Api
    module V3
      module Admin
        # Finds the editable email template a request is about, from its
        # dotted key, for the language the request names.
        module EmailTemplateLookup
          extend ActiveSupport::Concern

          included do
            scoped_resource :email_templates

            before_action :load_email_template

            rescue_from Spree::EmailTemplates::NoSampleRecord, with: :render_no_sample
            rescue_from Liquid::Error, MRML::Error, with: :render_render_error
          end

          private

          attr_reader :email_template

          def load_email_template
            @email_template = Spree::EmailTemplates::Entry.for_id(
              current_store, params[:email_template_id] || params[:id], locale: language
            )
          end

          # A language code, or "any" for the version every language uses. Named
          # `language` rather than `locale`, which picks the response's language.
          def language
            @language ||= params[:language].to_s.strip.presence || Spree::EmailTemplate::ANY_LOCALE
          end

          def serialize_email_template(reload: false)
            load_email_template if reload
            Spree.api.admin_email_template_serializer.new(email_template, params: serializer_params).to_h
          end

          def serializer_class
            Spree.api.admin_email_template_serializer
          end

          # Renders the template as it stands after a workflow ran, or why the
          # workflow refused.
          def render_email_template_result(result, status: :ok)
            return render_stale_draft if result.error&.value == :stale
            return render_template_problems(result.value) if result.error&.value == :invalid_template
            return render_result_error(result) unless result.success?

            render json: serialize_email_template(reload: true), status: status
          end

          # Every published version of the template in the requested language.
          def email_template_revisions
            Spree::EmailTemplateRevision.where(
              email_template: current_store.email_templates.for_key(email_template.key, language)
            )
          end

          # An unsaved subject and body are previewed only when sent, so an
          # empty body still previews as empty. `branding` previews unsaved
          # colors and font.
          def preview_arguments
            arguments = params.permit(:record_id, :subject, :body).to_h.symbolize_keys
            arguments[:locale] = language
            arguments[:email_key] = params[:email_key].to_s.tr('.', '/').presence
            arguments[:branding] = params.fetch(:branding, {}).permit(*Spree::Emails::Branding.attribute_names).to_h
            arguments
          end

          # Samples show a real record of the store (the latest order, a
          # company), so previewing one needs permission to read it.
          def authorize_sample_data!
            missing = sample_classes.flat_map { |sample| Array(sample.try(:required_permissions)) }.uniq.
                      reject { |key| holds_permission?(key) }
            return if missing.empty?

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: Spree.t('email_templates.sample_needs_permission', permissions: missing.to_sentence),
              status: :forbidden,
              details: { required_scope: missing.first }
            )
          end

          # A preview shows one email; publishing the layout or a partial
          # renders every email, so it needs what all of their samples need.
          def sample_classes
            if action_name == 'create' && controller_name == 'publications' && !email_template.definition.email?
              Spree.editable_email_templates.emails.map(&:sample_class)
            else
              [build_preview.email.sample_class]
            end
          end

          def build_preview
            Spree::EmailTemplates::Preview.new(store: current_store, key: email_template.key, strict: true, **preview_arguments)
          end

          def render_template_problems(problems)
            problems = problems.map { |problem| problem.merge(email: problem[:email].tr('/', '.')) }

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:email_template_invalid],
              message: problems.map { |problem| problem[:message] }.uniq.to_sentence,
              status: :unprocessable_content,
              details: { problems: problems }
            )
          end

          # Attributed to the template being edited, whose lines the editor marks.
          def render_render_error(error)
            render_template_problems([{ email: email_template.id, message: error.message, line: error.try(:line_number) }])
          end

          def render_no_sample(error)
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:email_template_no_sample],
              message: error.message,
              status: :unprocessable_content
            )
          end

          def render_stale_draft
            saved_by = email_template.draft&.updated_by&.actor_label

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:email_template_stale],
              message: Spree.t('email_templates.stale_draft', name: saved_by || Spree.t('email_templates.another_admin')),
              status: :conflict,
              details: { updated_by: saved_by }
            )
          end
        end
      end
    end
  end
end
