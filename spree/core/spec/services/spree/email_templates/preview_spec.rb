require 'spec_helper'

describe Spree::EmailTemplates::Preview do
  include_context 'with an editable email template'

  let(:store) { @default_store }

  it 'renders an unsaved draft with sample data, and keeps the variables it used' do
    preview = described_class.new(store: store, key: editable_key, subject: 'Hi {{ user.first_name }}',
                                  body: '<mj-section><mj-column><mj-text>Draft for {{ user.email }}</mj-text></mj-column></mj-section>')

    email = preview.call

    expect(email.subject).to eq('Hi Ann')
    expect(email.html).to include('Draft for ann@example.com', store.name)
    expect(preview.variables.keys).to include('user', 'reset_url', 'store', 'locale')
  end

  it 'shows the layout inside an email that uses it' do
    layout = File.read(Spree::Core::Engine.root.join('app/views/layouts/spree/base_mailer.liquid')).sub('{{ content_for_layout }}', 'LAYOUT DRAFT {{ content_for_layout }}')

    email = described_class.new(store: store, key: 'layouts/spree/base_mailer', body: layout).call

    expect(email.html).to include('LAYOUT DRAFT')
  end
end
