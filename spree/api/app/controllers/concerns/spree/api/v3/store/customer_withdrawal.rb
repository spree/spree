module Spree
  module Api
    module V3
      module Store
        # Withdrawing a return or exchange the customer opened. Only while it
        # is still `requested`: once the merchant has approved it, and possibly
        # bought a label, withdrawing is theirs. The workflow re-checks that
        # under a row lock, so a merchant approving at the same moment wins.
        module CustomerWithdrawal
          extend ActiveSupport::Concern

          # PATCH .../:id/cancel
          def cancel
            result = cancel_workflow.call(workflow_record_key => @resource, only_from: %w[requested])
            return render_result(result) unless result.failure? && result.error.value == :not_cancellable

            @resource.errors.add(:base, :not_cancelable, message: I18n.t('spree.return_errors.not_cancelable'))
            render_validation_error(@resource.errors)
          end
        end
      end
    end
  end
end
