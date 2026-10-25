module Spree
  module Api
    module V3
      module Admin
        # A rendered preview of an email template, with the variables it was
        # rendered with, as example values for the editor.
        class EmailTemplatePreviewSerializer < V3::BaseSerializer
          typelize id: [:string, nullable: true],
                   subject: :string,
                   html: :string,
                   text: :string,
                   email_key: :string,
                   variables: 'Record<string, unknown>'

          attribute :subject do |preview|
            preview.rendered.subject
          end

          attribute :html do |preview|
            preview.rendered.html
          end

          attribute :text do |preview|
            preview.rendered.text
          end

          # The email the preview renders: the template itself, or for the
          # layout and partials, the email shown around them.
          attribute :email_key do |preview|
            preview.email.key.tr('/', '.')
          end

          attribute :variables, &:variables
        end
      end
    end
  end
end
