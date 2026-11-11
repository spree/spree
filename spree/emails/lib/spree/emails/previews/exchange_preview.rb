require 'spree/core/previews/preview_data'

# Preview Spree exchange emails at /rails/mailers/spree/exchange
module Spree
  class ExchangePreview < ActionMailer::Preview
    include Spree::PreviewData::LocaleParam

    def requested_email
      Spree::ExchangeMailer.requested_email(localized(Spree::Exchange.last))
    end

    def approved_email
      Spree::ExchangeMailer.approved_email(localized(Spree::Exchange.where.not(status: %w[requested canceled]).last || Spree::Exchange.last))
    end

    private

    def localized(exchange)
      exchange.order.locale = locale if exchange && locale.present?
      exchange
    end
  end
end
