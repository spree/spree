module Spree
  # Stored under this name in `type` columns since 5.x, so it is kept.
  class PaymentSessions::Adyen < PaymentSession
    # @return [String, nil] what Drop-in loads the session with
    def session_data
      external_data&.dig('session_data')
    end

    # Whether Spree made the session payable; after that its amount is fixed.
    def payable?
      ActiveModel::Type::Boolean.new.cast(external_data&.dig('payable')) || false
    end

    # What the session asked Adyen for at creation, so a webhook is mapped by
    # it rather than by the method's setting when the webhook arrives.
    def manual_capture?
      ActiveModel::Type::Boolean.new.cast(external_data&.dig('manual_capture')) || false
    end

    # Nothing reaches the webhook path to build it from, so the source is
    # attached by apply_settlement_metadata from the report instead.
    def payment_source_for_settlement
      nil
    end

    # Records the PSP reference and the variant, and attaches the source the
    # report describes. Never merges the raw report.
    #
    # @param payment [Spree::Payment] unsaved
    # @param metadata [Hash] SpreeAdyen::Result#to_h
    def apply_settlement_metadata(payment, metadata)
      result = SpreeAdyen::Result.from_h(metadata)
      payment.metadata = payment.metadata.merge(
        'adyen_psp_reference' => result.psp_reference, 'adyen_variant' => result.variant
      ).compact
      payment.source = settlement_source(result)
    end

    # The PSP reference, written on the capture event of a payment that settles
    # as captured, so a late CAPTURE_FAILED finds it.
    def capture_reference_for_settlement(payment)
      payment.metadata['adyen_psp_reference']
    end

    private

    def settlement_source(result)
      return if result.psp_reference.blank?

      if SpreeAdyen::Variants.card?(result.variant)
        return payment_method.credit_card_from(result, customer: customer) if result.stored_payment_method_id.present? && customer

        return SpreeAdyen::PaymentSources::Card.create!(
          payment_method: payment_method, customer: customer, gateway_payment_profile_id: result.psp_reference,
          adyen_variant: result.variant, brand: SpreeAdyen::Variants.card_brand(result.variant),
          last_digits: result.card_summary, wallet: SpreeAdyen::Variants.wallet(result.variant)
        )
      end

      SpreeAdyen::Variants.source_class(result.variant).create!(
        payment_method: payment_method, customer: customer, gateway_payment_profile_id: result.psp_reference,
        adyen_variant: result.variant
      )
    end
  end
end
