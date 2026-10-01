module Spree
  module EmailTemplates
    # Copies a published revision into the draft, to be checked and
    # published like any other change. A revision of the version for every
    # language can be restored into one language's draft (`locale`).
    class RestoreRevision < Spree::Workflow
      def perform(revision:, actor: nil, lock_version: nil, locale: nil)
        super
        template = revision.email_template

        Spree.email_template_save_draft_workflow.call(
          store: template.store, key: template.key, locale: locale.presence || template.locale, actor: actor,
          attributes: { subject: revision.subject, body: revision.body, lock_version: lock_version }
        )
      end
    end
  end
end
