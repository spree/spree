module Spree
  module EmailTemplates
    # Copies a published revision into the draft, to be checked and
    # published like any other change. A revision of the version for every
    # language can be restored into one language's draft (`locale`).
    class RestoreRevision < Spree::Workflow
      # @param draft_version [Hash] `{ lock_version: }` to check the draft as saving does; empty checks nothing
      def perform(revision:, actor: nil, locale: nil, draft_version: {})
        super
        template = revision.email_template
        target_locale = locale.presence || template.locale

        Spree.email_template_save_draft_workflow.call(
          store: template.store, key: template.key, locale: target_locale, actor: actor,
          attributes: {
            subject: readable(revision.subject, target_locale, escape: false),
            body: readable(revision.body, target_locale),
            **draft_version.slice(:lock_version)
          }
        )
      end

      private

      # A shared revision restored into one language reads in that language's words.
      def readable(text, target_locale, escape: true)
        return text if target_locale == Spree::EmailTemplate::ANY_LOCALE

        Spree::Emails::TranslationInliner.call(text, locale: target_locale, escape: escape)
      end
    end
  end
end
