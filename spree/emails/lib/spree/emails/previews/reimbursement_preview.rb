require 'spree/core/previews/preview_data'

# Preview Spree reimbursement emails at /rails/mailers/spree/reimbursement
class Spree::ReimbursementPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def reimbursement_email
    reimbursement = Spree::Reimbursement.last
    reimbursement.order.locale = locale if reimbursement && locale.present?
    Spree::ReimbursementMailer.reimbursement_email(reimbursement)
  end
end
