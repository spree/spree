module Spree
  module EmailTemplates
    # Saves a draft of an editable email template, in any state: it is work
    # in progress and customers keep receiving the published version. The
    # first save starts from what is published, else Spree's default, and
    # remembers that default so an upgrade changing it can be spotted.
    #
    # A save carrying an older `lock_version` than the draft has is refused,
    # so two admins editing at once cannot overwrite each other. `rebase`
    # marks the draft as based on Spree's current default, for a merchant who
    # reviewed an upgraded default and keeps their own version.
    class SaveDraft < Spree::Workflow
      def perform(store:, key:, attributes:, locale: Spree::EmailTemplate::ANY_LOCALE, actor: nil)
        super
        step :ensure_editable
        step :ensure_current
        step :save

        success(draft)
      end

      private

      def draft
        @draft ||= store.email_template_drafts.find_or_initialize_by(key: key, locale: locale)
      end

      def ensure_editable
        failure(nil, :not_editable) unless Spree.editable_email_templates.include?(key)
      end

      # Without `lock_version` nothing is checked. `nil` says the caller saw no
      # draft, so one saved since is refused rather than overwritten.
      def ensure_current
        return unless attributes.key?(:lock_version)

        expected = attributes[:lock_version]
        if expected.nil?
          failure(nil, :stale) if draft.persisted?
        elsif draft.new_record? || expected.to_i != draft.lock_version
          # A draft that is gone was published or discarded since it was loaded.
          failure(nil, :stale)
        end
      end

      def save
        start_from_current if draft.new_record?
        rebase if ActiveModel::Type::Boolean.new.cast(attributes[:rebase])
        draft.subject = attributes[:subject] if attributes.key?(:subject)
        draft.body = attributes[:body] if attributes.key?(:body)
        draft.updated_by = actor
        failure(draft) unless draft.save
      rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique
        failure(nil, :stale)
      end

      # Starts from what customers in this language receive, with Spree's
      # translation keys written out as text in it.
      def start_from_current
        published = store.email_templates.published.where(key: key, locale: [draft.locale, Spree::EmailTemplate::ANY_LOCALE]).
                    min_by { |template| template.locale == draft.locale ? 0 : 1 }

        draft.subject = readable(published&.subject || default&.subject)
        draft.body = readable(published&.body || default&.body)
        draft.base_subject = published ? published.base_subject : default&.subject
        draft.base_body = published ? published.base_body : default&.body
      end

      def rebase
        draft.base_subject = default&.subject
        draft.base_body = default&.body
      end

      def readable(text)
        return text if draft.locale == Spree::EmailTemplate::ANY_LOCALE

        Spree::Emails::TranslationInliner.call(text, locale: draft.locale)
      end

      def default
        @default ||= Spree::Emails::TemplateResolver.for_mailers.find_default(key)
      end
    end
  end
end
