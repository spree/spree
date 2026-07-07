require_relative 'preview_data'

# Preview Spree admin user auth emails at /rails/mailers/spree/admin_user
class Spree::AdminUserPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def password_reset_email
    Spree::AdminUserMailer.password_reset_email(
      Spree::PreviewData.admin_user,
      'preview-token',
      Spree::PreviewData.store(locale)
    )
  end

  def confirmation_email
    Spree::AdminUserMailer.confirmation_email(
      Spree::PreviewData.admin_user,
      'preview-token',
      Spree::PreviewData.store(locale)
    )
  end
end
