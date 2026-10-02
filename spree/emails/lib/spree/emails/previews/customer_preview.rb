require 'spree/core/previews/preview_data'

# Preview Spree customer account emails at /rails/mailers/spree/customer
class Spree::CustomerPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def password_reset_email
    Spree::CustomerMailer.password_reset_email(
      Spree::PreviewData.customer,
      'preview-token',
      Spree::PreviewData.store(locale)
    )
  end

  def data_export_email
    Spree::CustomerMailer.data_export_email(Spree::DataRequest.access.with_status(:completed).last)
  end
end
