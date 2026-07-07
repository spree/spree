require_relative 'preview_data'

# Preview Spree invitation emails at /rails/mailers/spree/invitation
class Spree::InvitationPreview < ActionMailer::Preview
  def invitation_email
    Spree::InvitationMailer.invitation_email((locale.blank? && Spree::Invitation.pending.last) || example_invitation)
  end

  def invitation_accepted
    Spree::InvitationMailer.invitation_accepted((locale.blank? && Spree::Invitation.accepted.last) || example_invitation(accepted: true))
  end

  private

  # Build an in-memory invitation so the preview works on a database with no
  # invitations. When the preview toolbar requests a locale, its store carries
  # that locale. Never saved, so no records are created.
  def example_invitation(accepted: false)
    store = Spree::PreviewData.store(locale)
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

  def locale
    @params[:locale]
  end
end
