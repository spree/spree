module Spree
  module Api
    module V3
      module Admin
        # An editable email template for one language: what customers receive
        # now (the store's published version, else Spree's default), Spree's
        # default, and the draft in progress.
        class EmailTemplateSerializer < V3::BaseSerializer
          typelize key: :string,
                   kind: [:string, enum: Spree::Emails::EditableTemplates::KINDS.map(&:to_s)],
                   language: :string,
                   customized: :boolean,
                   customized_languages: [:string, multi: true],
                   subject: [:string, nullable: true],
                   body: :string,
                   published_at: [:string, nullable: true],
                   default_subject: [:string, nullable: true],
                   default_body: :string,
                   default_changed: :boolean,
                   base_subject: [:string, nullable: true],
                   base_body: [:string, nullable: true],
                   draft: ['EmailTemplateDraft', nullable: true]

          attributes :key, :subject, :body

          # A language code, or `any` for the version every language uses.
          attribute :language, &:locale

          attribute :customized_languages, &:customized_locales

          attribute :kind do |entry|
            entry.kind.to_s
          end

          attribute :customized, &:customized?

          attribute :published_at do |entry|
            entry.published&.published_at&.iso8601
          end

          attribute :default_subject do |entry|
            entry.default&.subject
          end

          attribute :default_body do |entry|
            entry.default&.body
          end

          attribute :default_changed do |entry|
            entry.outdated_version.present?
          end

          # The default the store's version started from, when Spree's default
          # has changed since: compare it with `default_body` to see what changed.
          attribute :base_subject do |entry|
            entry.outdated_version&.base_subject
          end

          attribute :base_body do |entry|
            entry.outdated_version&.base_body
          end

          one :draft, resource: proc { Spree.api.admin_email_template_draft_serializer }
        end
      end
    end
  end
end
