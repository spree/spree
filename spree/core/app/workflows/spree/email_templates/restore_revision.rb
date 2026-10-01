module Spree
  module EmailTemplates
    # Copies a published revision into the draft, to be checked and
    # published like any other change.
    class RestoreRevision < Spree::Workflow
      def perform(revision:, actor: nil, lock_version: nil)
        super
        template = revision.email_template

        Spree.email_template_save_draft_workflow.call(
          store: template.store, key: template.key, locale: template.locale, actor: actor,
          attributes: { subject: revision.subject, body: revision.body, lock_version: lock_version }
        )
      end
    end
  end
end
