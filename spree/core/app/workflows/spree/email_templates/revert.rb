module Spree
  module EmailTemplates
    # Goes back to Spree's default for one template and language: the
    # published version is marked reverted, so the file answers again, and
    # any draft is discarded. The row and its revisions stay, so the history
    # can still be restored.
    class Revert < Spree::Workflow
      def perform(store:, key:, locale: Spree::EmailTemplate::ANY_LOCALE, actor: nil)
        super
        locale_value = locale.presence || Spree::EmailTemplate::ANY_LOCALE
        template = store.email_templates.find_by(key: key, locale: locale_value)

        ApplicationRecord.transaction do
          store.email_template_drafts.where(key: key, locale: locale_value).destroy_all
          template&.update!(status: :reverted, reverted_at: Time.current, reverted_by: actor) if template&.published?
        end

        template&.publish_event('email_template.reverted') if template&.reverted?
        success(template)
      end
    end
  end
end
