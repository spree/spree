# Preview Spree reimbursement emails at /rails/mailers/spree/reimbursement
class Spree::ReimbursementPreview < ActionMailer::Preview
  def reimbursement_email
    reimbursement = Spree::Reimbursement.last
    reimbursement.order.locale = locale if reimbursement && locale.present?
    Spree::ReimbursementMailer.reimbursement_email(reimbursement)
  end

  private

  def locale
    @params[:locale]&.downcase
  end
end
