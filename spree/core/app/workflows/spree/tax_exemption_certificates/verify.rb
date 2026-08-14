module Spree
  module TaxExemptionCertificates
    # Accepts a certificate as evidence, which is what makes it count at
    # estimate time.
    #
    # A workflow rather than a plain update because of the +validate+ hook: a
    # merchant who checks a resale number against a state registry, or requires
    # a second pair of eyes above a threshold, needs somewhere to refuse before
    # the certificate starts exempting sales. Hook keys are public API, so this
    # one is placed while 6.0 is still open.
    class Verify < Spree::Workflow
      hooks :validate, :after_verify

      # @param certificate [Spree::TaxExemptionCertificate]
      # @param verified_by [Object, nil] the staff member accepting it
      def perform(certificate:, verified_by: nil)
        super

        step :ensure_verifiable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_verified
        end

        run_hooks :after_verify
        certificate.publish_event('tax_exemption_certificate.verified')
        success(certificate.reload)
      end

      private

      # Only a pending certificate is awaiting a decision. Re-verifying a
      # revoked one would resurrect evidence somebody withdrew.
      def ensure_verifiable
        failure(certificate, :not_pending) unless certificate.pending?
      end

      def mark_verified
        certificate.update!(
          status: 'verified',
          verified_at: Time.current,
          verified_by: verified_by || certificate.verified_by
        )
      end
    end
  end
end
