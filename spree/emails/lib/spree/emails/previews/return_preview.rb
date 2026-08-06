require 'spree/core/previews/preview_data'

# Preview Spree return emails at /rails/mailers/spree/return
class Spree::ReturnPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def refunded_email
    return_record = Spree::Return.refunded.last
    return_record.order.locale = locale if return_record && locale.present?
    Spree::ReturnMailer.refunded_email(return_record)
  end
end
