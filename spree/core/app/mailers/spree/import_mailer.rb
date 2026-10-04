module Spree
  class ImportMailer < Spree::BaseMailer
    def import_done(import)
      @import = import

      with_store_locale(@import.store) do
        mail_template(
          { import: email_data(@import, Spree::Emails::ImportSerializer) },
          to: @import.user.email, store_url: current_store.url
        )
      end
    end

    def current_store
      @current_store ||= @import.store
    end
  end
end
