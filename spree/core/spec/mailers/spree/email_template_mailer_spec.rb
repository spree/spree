require 'spec_helper'

describe Spree::EmailTemplateMailer, type: :mailer do
  include_context 'with an editable email template'

  let(:store) { @default_store }

  it 'sends the unsaved template, rendered with sample data, marked as a test' do
    mail = described_class.test_email(store, 'admin@example.com', editable_key,
                                      subject: 'Hi {{ user.first_name }}',
                                      body: '<mj-section><mj-column><mj-text>Draft for {{ user.email }}</mj-text></mj-column></mj-section>')

    expect(mail.to).to eq(['admin@example.com'])
    expect(mail.subject).to eq('[Test] Hi Ann')
    expect(mail.html_part.body.to_s).to include('Draft for ann@example.com')
    expect(mail.text_part.body.to_s).to include('Draft for ann@example.com')
  end

  it 'renders unsaved branding' do
    mail = described_class.test_email(store, 'admin@example.com', editable_key, branding: { card_color: '#123456' })

    expect(mail.html_part.body.to_s).to include('#123456')
  end
end
