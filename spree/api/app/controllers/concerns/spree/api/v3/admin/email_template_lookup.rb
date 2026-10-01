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
            @email_template = Spree::EmailTemplates::Entry.find(
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

          def render_render_error(error)
            email = params[:email_key].presence || email_template.id
            render_template_problems([{ email: email.to_s, message: error.message, line: error.try(:line_number) }])
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
