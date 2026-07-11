module Spree
  class ImportMailer < Spree::BaseMailer
    def import_done(import)
      @import = import

      with_store_locale(@import.store) do
        mail(
          to: @import.user.email,
          subject: Spree.t('import_mailer.import_done.subject', import_number: @import.number).to_s,
          store_url: current_store.url
        )
      end
    end

    def current_store
      @current_store ||= @import.store
    end
  end
end
