module Spree
  # Sends an editable email template, rendered with sample data as the editor
  # previews it, so a merchant can see it in a real inbox before publishing.
  class EmailTemplateMailer < BaseMailer
    # @param store [Spree::Store]
    # @param recipient [String] the email address of the admin who asked for it
    # @param key [String] the editable template
    # @param locale [String] a language code, or "any"
    # @param subject [String, nil] an unsaved subject
    # @param body [String, nil] an unsaved body
    # @param record_id [String, nil] the record to build sample data from
    # @param email_key [String, nil] for the layout or a partial, the email to show it in
    def test_email(store, recipient, key, locale: nil, subject: nil, body: nil, record_id: nil, email_key: nil)
      @current_store = store
      email = Spree::EmailTemplates::Preview.new(
        store: store, key: key, locale: locale, subject: subject, body: body, record_id: record_id, email_key: email_key
      ).call

      mail(to: recipient, subject: Spree.t('email_templates.test_email_subject', subject: email.subject)) do |format|
        format.text { render plain: email.text, layout: false }
        format.html { render html: email.html.html_safe, layout: false }
      end
    end
  end
end
