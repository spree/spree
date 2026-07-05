# Preview Spree reimbursement emails at /rails/mailers/spree/reimbursement
class Spree::ReimbursementPreview < ActionMailer::Preview
  def reimbursement_email
    Spree::ReimbursementMailer.reimbursement_email(Spree::Reimbursement.last)
  end
end
