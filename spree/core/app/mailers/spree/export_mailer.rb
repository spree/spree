module Spree
  class ExportMailer < Spree::BaseMailer
    def export_done(export)
      @export = export

      with_store_locale(@export.store) do
        mail(
          to: @export.user.email,
          subject: Spree.t('export_mailer.export_done.subject', export_number: @export.number).to_s,
          store_url: current_store.url
        )
      end
    end

    def current_store
      @current_store ||= @export.store
    end
  end
end
