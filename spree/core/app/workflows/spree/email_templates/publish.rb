module Spree
  module EmailTemplates
    # Makes a draft live. The draft is first rendered the way customers would
    # receive it (see Spree::EmailTemplates::Check); a draft that does not
    # render is refused with what is wrong and where, so an email already
    # being sent can never break. Publishing records a revision and clears
    # the draft. Given the `lock_version` the draft was reviewed at, a draft
    # saved since is refused rather than published unseen.
    class Publish < Spree::Workflow
      def perform(store:, key:, locale: Spree::EmailTemplate::ANY_LOCALE, actor: nil, lock_version: nil)
        super
        step :ensure_draft
        step :ensure_current
        step :check

        begin
          ApplicationRecord.transaction do
            step :publish
            step :record_revision
            step :clear_draft
          end
        rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique
          failure(nil, :stale)
        end

        template.publish_event('email_template.published')
        success(template)
      end

      private

      def draft
        @draft ||= store.email_template_drafts.find_by(key: key, locale: locale.presence || Spree::EmailTemplate::ANY_LOCALE)
      end

      def template
        @template ||= store.email_templates.find_or_initialize_by(key: draft.key, locale: draft.locale)
      end

      def ensure_draft
        failure(nil, :no_draft) unless draft
      end

      def ensure_current
        failure(nil, :stale) if !lock_version.nil? && lock_version.to_i != draft.lock_version
      end

      def check
        problems = Spree::EmailTemplates::Check.new(store: store, draft: draft).call
        failure(problems, :invalid_template) if problems.any?
      end

      def publish
        template.assign_attributes(
          subject: draft.subject, body: draft.body, base_subject: draft.base_subject, base_body: draft.base_body,
          status: :published, published_at: Time.current, published_by: actor, reverted_at: nil, reverted_by: nil
        )
        template.save!
      end

      def record_revision
        template.revisions.create!(subject: template.subject, body: template.body, published_by: actor)
      end

      def clear_draft
        draft.destroy!
      end
    end
  end
end
