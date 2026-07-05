module Spree
  class ExportMailer < Spree::BaseMailer
    def export_done(export)
      @export = export

      mail(
        to: @export.user.email,
        subject: Spree.t('export_mailer.export_done.subject', export_number: @export.number).to_s,
        from: from_address,
        reply_to: reply_to_address,
        store_url: current_store.url
      )
    end

    def current_store
      @current_store ||= @export.store
    end
  end
end
