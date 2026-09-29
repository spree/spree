require 'spec_helper'

describe 'ERB emails', type: :mailer do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store, email: 'buyer@example.com') }
  let(:app_view) { Rails.root.join('app/views/spree/order_mailer/confirm_email.liquid') }

  before { allow(Spree::Deprecation).to receive(:warn) }

  it 'renders the pre-6.0 ERB email while the gem is installed' do
    message = Spree::OrderMailer.confirm_email(order)

    expect(email_body(message)).to include('email-wrapper')
    expect(message.text_part.decoded).to include(order.number)
  end

  it 'takes the subject from the Liquid template' do
    expect(Spree::OrderMailer.confirm_email(order).subject).to eq("#{store.name} Order Confirmation ##{order.number}")
  end

  it 'warns once that ERB emails are deprecated' do
    Spree::Emails::LegacyTemplates.instance_variable_set(:@warned, nil)
    2.times { Spree::OrderMailer.confirm_email(order).message }

    expect(Spree::Deprecation).to have_received(:warn).with(/spree\/order_mailer\/confirm_email/).once
  end

  context 'when the app has ported the email to Liquid' do
    before do
      FileUtils.mkdir_p(app_view.dirname)
      File.write(app_view, <<~LIQUID)
        ---
        subject: "Ported {{ order.number }}"
        ---
        <mj-section><mj-column><mj-text>Ported email</mj-text></mj-column></mj-section>
      LIQUID
    end

    after { FileUtils.rm_f(app_view) }

    it 'renders the Liquid template instead' do
      message = Spree::OrderMailer.confirm_email(order)

      expect(message.subject).to eq("Ported #{order.number}")
      expect(email_body(message)).to include('Ported email')
      expect(email_body(message)).not_to include('email-wrapper')
    end
  end
end
