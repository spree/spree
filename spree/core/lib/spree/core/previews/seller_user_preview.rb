require_relative 'preview_data'

# Preview Spree seller panel auth emails at /rails/mailers/spree/seller_user
class Spree::SellerUserPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def password_reset_email
    Spree::SellerUserMailer.password_reset_email(
      Spree::PreviewData.admin_user,
      'preview-token',
      Spree::PreviewData.store(locale)
    )
  end
end
