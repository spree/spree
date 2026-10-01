module Spree
  module EmailTemplates
    # One editable email template for one store and language, as the editor
    # shows it: what customers receive now, the draft in progress and
    # Spree's default.
    class Entry
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :definition
      attribute :locale, :string, default: Spree::EmailTemplate::ANY_LOCALE
      attribute :published
      attribute :draft
      attribute :customized_locales, default: -> { [] }

      delegate :key, :kind, to: :definition

      # @param store [Spree::Store]
      # @param locale [String] a language code, or "any"
      # @return [Array<Spree::EmailTemplates::Entry>] every editable template
      def self.all(store, locale: Spree::EmailTemplate::ANY_LOCALE)
        published = store.email_templates.published.where(locale: locale).index_by(&:key)
        drafts = store.email_template_drafts.where(locale: locale).includes(:updated_by).index_by(&:key)
        customized = store.email_templates.published.pluck(:key, :locale).group_by(&:first)

        Spree.editable_email_templates.map do |definition|
          new(definition: definition, locale: locale, published: published[definition.key], draft: drafts[definition.key],
              customized_locales: customized.fetch(definition.key, []).map(&:last).sort)
        end
      end

      # @param store [Spree::Store]
      # @param id [String] the template's key with dots, e.g. "spree.order_mailer.confirm_email"
      # @param locale [String]
      # @return [Spree::EmailTemplates::Entry]
      # @raise [ActiveRecord::RecordNotFound] when no editable template has that id
      def self.find(store, id, locale: Spree::EmailTemplate::ANY_LOCALE)
        definition = Spree.editable_email_templates[id.to_s.tr('.', '/')]
        raise ActiveRecord::RecordNotFound, "Couldn't find email template #{id}" unless definition

        locale = locale.presence || Spree::EmailTemplate::ANY_LOCALE
        new(
          definition: definition, locale: locale,
          published: store.email_templates.published.for_key(definition.key, locale).first,
          draft: store.email_template_drafts.for_key(definition.key, locale).first,
          customized_locales: store.email_templates.published.where(key: definition.key).order(:locale).pluck(:locale)
        )
      end

      # The key with dots, so it fits in a URL segment.
      def id
        key.tr('/', '.')
      end
      alias prefixed_id id

      def customized?
        published.present?
      end

      # @return [Spree::Emails::Template, nil] the template file Spree or the app ships
      def default
        @default ||= Spree::Emails::TemplateResolver.for_mailers.find_default(key)
      end

      # What customers receive now.
      def subject
        customized? ? published.subject : default&.subject
      end

      def body
        customized? ? published.body : default&.body
      end

      # The default the store's version started from, when Spree's default has
      # changed since, so the editor can show what changed.
      #
      # @return [Spree::EmailTemplate, Spree::EmailTemplateDraft, nil]
      def outdated_version
        [draft, published].compact.find { |version| version.default_changed?(default) }
      end
    end
  end
end
