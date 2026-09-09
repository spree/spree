module Spree
  module Seeds
    class ReturnsEnvironment
      prepend Spree::ServiceModule::Base

      RETURN_REASONS = [
        'Better price available',
        'Missed estimated delivery date',
        'Missing parts or accessories',
        'Damaged/Defective',
        'Different from what was ordered',
        'Different from description',
        'No longer needed/wanted',
        'Accidental order',
        'Unauthorized purchase'
      ].freeze

      # Why an order was called off before it shipped — a different question
      # from why goods came back; see Spree::OrderCancellationReason.
      ORDER_CANCELLATION_REASONS = [
        'Customer changed their mind',
        'Payment declined',
        'Suspected fraud',
        'Out of stock',
        'Duplicate order',
        'Staff error',
        'Order expired'
      ].freeze

      # Why the merchant got it wrong, rather than why the customer changed
      # their mind — see Spree::ClaimReason.
      CLAIM_REASONS = [
        'Arrived damaged',
        'Never arrived',
        'Wrong item sent',
        'Missing item from order',
        'Item not as described'
      ].freeze

      def call
        # Every vocabulary is store-owned, so every store gets its own.
        Spree::Store.all.find_each do |store|
          # Through the model helper, not a literal — the workflows look this
          # row up by the same constant, so a hard-coded string here would
          # silently create a second, unfindable reason if the name ever moves.
          Spree::RefundReason.return_processing_reason(store)

          RETURN_REASONS.each { |name| Spree::ReturnReason.where(store: store).find_or_create_by!(name: name) }
          CLAIM_REASONS.each { |name| Spree::ClaimReason.where(store: store).find_or_create_by!(name: name) }
          ORDER_CANCELLATION_REASONS.each { |name| Spree::OrderCancellationReason.where(store: store).find_or_create_by!(name: name) }
        end
      end
    end
  end
end
