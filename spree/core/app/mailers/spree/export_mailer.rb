module Spree
  class ExportMailer < Spree::BaseMailer
    def export_done(export)
      @export = export

      with_store_locale(@export.store) do
        mail_template(
          { export: email_data(@export, Spree::Emails::ExportSerializer) },
          to: @export.user.email, store_url: current_store.url
        )
      end
    end

    def current_store
      @current_store ||= @export.store
    end
  end
end
