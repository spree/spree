# Registers core's staff password reset as an editable email for the length
# of an example, with a fixed sample, so specs in any engine can exercise the
# template editor without spree_emails' customer emails. Restores whatever was
# registered under the key before.
#
#   RSpec.describe '...' do
#     include_context 'with an editable email template'
#   end
module Spree
  module TestingSupport
    class EmailTemplateSample
      def self.record_type
        nil
      end

      def initialize(store:, record_id: nil)
        @store = store
      end

      def currency
        @store.default_currency
      end

      def variables
        {
          user: { 'first_name' => 'Ann', 'email' => 'ann@example.com' },
          reset_url: "#{@store.storefront_url}/reset-password?token=preview"
        }
      end
    end
  end
end

RSpec.shared_context 'with an editable email template' do
  let(:editable_key) { 'spree/admin_user_mailer/password_reset_email' }

  around do |example|
    registry = Spree.editable_email_templates
    previous = registry[editable_key]
    previous_layout = registry['layouts/spree/base_mailer']
    registry.register(editable_key, kind: :email, sample: 'Spree::TestingSupport::EmailTemplateSample')
    registry.register('layouts/spree/base_mailer', kind: :layout)
    example.run
  ensure
    previous ? registry.register(previous.key, kind: previous.kind, sample: previous.sample) : registry.delete(editable_key)
    previous_layout ? registry.register(previous_layout.key, kind: :layout) : registry.delete('layouts/spree/base_mailer')
  end
end
