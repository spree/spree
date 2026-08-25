module Spree
  # Functional mail for the company directory — currently the invitation that
  # brings a not-yet-registered buyer into a company node. Like the staff
  # invitation, this is transactional, not marketing: the no-welcome-email
  # rule on customer creation is untouched.
  class CompanyMailer < BaseMailer
    helper Spree::MailHelper

    # The invite carries the plaintext token; the storefront owns the
    # acceptance page, so the link resolves against the store URL like other
    # customer-facing links.
    #
    # @param invitation [Spree::CompanyInvitation, Integer]
    def invitation_email(invitation)
      @invitation = invitation.respond_to?(:id) ? invitation : Spree::CompanyInvitation.find(invitation)
      @company = @invitation.company
      store = @company.store
      @accept_url = append_token(invitation_base_url(store), @invitation.token)

      with_store_locale(store) do
        mail(
          to: @invitation.email,
          subject: "#{store.name} #{Spree.t('company_mailer.invitation_email.subject', company: @company.name)}",
          store_url: store.storefront_url
        )
      end
    end

    private

    def invitation_base_url(store)
      "#{store.storefront_url.to_s.chomp('/')}/account/company-invitation"
    end
  end
end
