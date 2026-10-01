module Spree
  module EmailTemplates
    # Renders a draft the way customers would receive it, with sample data
    # and strict variables, and reports what stops it from rendering. A
    # draft of the layout or a shared partial is checked inside every
    # editable email, since all of them use it.
    #
    # An email the store has no record for cannot be rendered with data; its
    # draft is still checked for Liquid syntax errors.
    class Check
      # @param store [Spree::Store]
      # @param draft [Spree::EmailTemplateDraft]
      def initialize(store:, draft:)
        @store = store
        @draft = draft
      end

      # @return [Array<Hash>] one `{ email:, message:, line: }` per problem; empty when the draft renders
      def call
        email_keys.filter_map { |email_key| problem_in(email_key) }
      end

      private

      def email_keys
        definition = @draft.definition
        definition.email? ? [definition.key] : Spree.editable_email_templates.emails.map(&:key)
      end

      def problem_in(email_key)
        Preview.new(store: @store, key: @draft.key, locale: @draft.locale, subject: @draft.subject, body: @draft.body,
                    email_key: email_key, strict: true).call
        nil
      rescue Spree::EmailTemplates::NoSampleRecord
        syntax_problem(email_key)
      rescue Liquid::Error => e
        { email: email_key, message: e.message, line: e.line_number }
      rescue MRML::Error => e
        { email: email_key, message: e.message, line: nil }
      end

      def syntax_problem(email_key)
        Liquid::Template.parse(@draft.body, environment: Spree::Emails::Renderer.environment, line_numbers: true)
        Liquid::Template.parse(@draft.subject.to_s, environment: Spree::Emails::Renderer.environment)
        nil
      rescue Liquid::Error => e
        { email: email_key, message: e.message, line: e.line_number }
      end
    end
  end
end
