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

        Spree.email_template_save_draft_workflow.call(
          store: template.store, key: template.key, locale: locale.presence || template.locale, actor: actor,
          attributes: { subject: revision.subject, body: revision.body, **draft_version.slice(:lock_version) }
        )
      end
    end
  end
end
