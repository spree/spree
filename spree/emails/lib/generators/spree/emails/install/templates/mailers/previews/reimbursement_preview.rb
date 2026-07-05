class ReimbursementPreview < ActionMailer::Preview
  def reimbursement_email
    Spree::ReimbursementMailer.reimbursement_email(Spree::Reimbursement.first)
  end
end
