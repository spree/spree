require 'spree/core/previews/preview_data'

# Preview Spree return emails at /rails/mailers/spree/return
class Spree::ReturnPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def requested_email
    Spree::ReturnMailer.requested_email(localized(Spree::Return.last))
  end

  def approved_email
    Spree::ReturnMailer.approved_email(localized(Spree::Return.where(status: %w[approved received refunded]).last || Spree::Return.last))
  end

  def refunded_email
    return_record = Spree::Return.refunded.last
    return_record.order.locale = locale if return_record && locale.present?
    Spree::ReturnMailer.refunded_email(return_record)
  end

  private

  def localized(return_record)
    return_record.order.locale = locale if return_record && locale.present?
    return_record
  end
end
