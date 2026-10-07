require 'spree/core/previews/preview_data'

# Preview Spree company emails at /rails/mailers/spree/company
class Spree::CompanyPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def invitation_email
    Spree::CompanyMailer.invitation_email(Spree::CompanyInvitation.pending.last)
  end
end
