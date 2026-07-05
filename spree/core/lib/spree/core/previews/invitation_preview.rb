# Preview Spree invitation emails at /rails/mailers/spree/invitation
class Spree::InvitationPreview < ActionMailer::Preview
  def invitation_email
    Spree::InvitationMailer.invitation_email(Spree::Invitation.pending.last || Spree::Invitation.last)
  end

  def invitation_accepted
    Spree::InvitationMailer.invitation_accepted(Spree::Invitation.accepted.last || Spree::Invitation.last)
  end
end
