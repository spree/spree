module Spree
  module Seeds
    class ReturnsEnvironment
      prepend Spree::ServiceModule::Base

      def call
        Spree::RefundReason.find_or_create_by!(name: 'Return processing', mutable: false)
        [
          'Better price available',
          'Missed estimated delivery date',
          'Missing parts or accessories',
          'Damaged/Defective',
          'Different from what was ordered',
          'Different from description',
          'No longer needed/wanted',
          'Accidental order',
          'Unauthorized purchase',
        ].each do |name|
          Spree::ReturnAuthorizationReason.find_or_create_by!(name: name)
        end
        Spree::ReimbursementType.find_or_create_by!(name: 'Store Credit', type: 'Spree::ReimbursementType::StoreCredit')
        Spree::ReimbursementType.find_or_create_by!(name: 'Exchange', type: 'Spree::ReimbursementType::Exchange')
        Spree::ReimbursementType.find_or_create_by!(name: 'Original payment', type: 'Spree::ReimbursementType::OriginalPayment')
      end
    end
  end
end
