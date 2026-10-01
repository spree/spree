module Spree
  module EmailTemplates
    # Goes back to Spree's default for one template and language: the
    # published version is marked reverted, so the file answers again, and
    # any draft is discarded. The row and its revisions stay, so the history
    # can still be restored. Given the `lock_version` the draft was seen at,
    # a draft saved or published since is not thrown away.
    class Revert < Spree::Workflow
      def perform(store:, key:, locale: Spree::EmailTemplate::ANY_LOCALE, actor: nil, lock_version: nil)
        super
        template = store.email_templates.find_by(key: key, locale: locale)
        draft = store.email_template_drafts.find_by(key: key, locale: locale)
        return failure(nil, :stale) if !lock_version.nil? && lock_version.to_i != draft&.lock_version

        begin
          ApplicationRecord.transaction do
            draft&.destroy!
            template&.update!(status: :reverted, reverted_at: Time.current, reverted_by: actor) if template&.published?
          end
        rescue ActiveRecord::StaleObjectError
          return failure(nil, :stale)
        end

        template&.publish_event('email_template.reverted') if template&.reverted?
        success(template)
      end
    end
  end
end
