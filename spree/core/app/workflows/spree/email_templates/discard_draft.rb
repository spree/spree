module Spree
  module EmailTemplates
    # Throws away the draft of one template and language. Given the
    # `lock_version` the draft was seen at, a draft saved since is kept.
    class DiscardDraft < Spree::Workflow
      def perform(store:, key:, locale: Spree::EmailTemplate::ANY_LOCALE, lock_version: nil)
        super
        draft = store.email_template_drafts.find_by(key: key, locale: locale.presence || Spree::EmailTemplate::ANY_LOCALE)
        return success(nil) unless draft
        return failure(nil, :stale) if !lock_version.nil? && lock_version.to_i != draft.lock_version

        draft.destroy!
        success(nil)
      rescue ActiveRecord::StaleObjectError
        failure(nil, :stale)
      end
    end
  end
end
