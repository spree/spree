require_relative 'preview_data'

# Preview Spree invitation emails at /rails/mailers/spree/invitation
class Spree::InvitationPreview < ActionMailer::Preview
  def invitation_email
    Spree::InvitationMailer.invitation_email(Spree::Invitation.pending.last || example_invitation)
  end

  def invitation_accepted
    Spree::InvitationMailer.invitation_accepted(Spree::Invitation.accepted.last || example_invitation(accepted: true))
  end

  private

  # Build an in-memory invitation so the preview works on a database with no
  # invitations. Never saved, so no records are created.
  def example_invitation(accepted: false)
    store = Spree::Store.default
    admin = Spree::PreviewData.admin_user
    Spree::Invitation.new(
      id: 0,
      email: 'invitee@example.com',
      resource: store,
      inviter: admin,
      invitee: accepted ? admin : nil,
      role: Spree::Role.first || Spree::Role.new(name: 'admin'),
      token: 'preview-token',
      status: accepted ? 'accepted' : 'pending',
      expires_at: 7.days.from_now
    )
  end
end
