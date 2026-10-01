require 'spec_helper'

# Every customer email merchants may edit has to preview, and pass the
# publish check, with the sample data its builder makes.
describe 'editable email samples' do
  let(:store) { @default_store }

  before do
    order = create(:shipped_order, store: store)
    create(:received_return, store: store, order: order)
    create(:order_group, :with_parcels, store: store, sellers_count: 2)
  end

  it 'registers every customer email, the layout and the shared partials' do
    expect(Spree.editable_email_templates.emails.size).to eq(11)
    expect(Spree.editable_email_templates['layouts/spree/base_mailer']).to be_present
    expect(Spree.editable_email_templates['spree/order_mailer/store_owner_notification_email']).to be_nil
  end

  it 'previews every editable email strictly, with placeholder links' do
    Spree.editable_email_templates.emails.each do |email|
      preview = Spree::EmailTemplates::Preview.new(store: store, key: email.key, strict: true)
      rendered = preview.call

      expect(rendered.subject).to be_present, email.key
      expect(rendered.html).not_to include('{{', '<mj-'), email.key
      expect(preview.variables.to_json).not_to match(/token=(?!preview)/), email.key
    end
  end

  it 'previews with a record the merchant picks, only from the store' do
    order = create(:completed_order_with_totals, store: store)

    preview = Spree::EmailTemplates::Preview.new(store: store, key: 'spree/order_mailer/confirm_email', record_id: order.prefixed_id)

    expect(preview.call.subject).to include(order.number)
    other = create(:completed_order_with_totals, store: create(:store))
    expect do
      Spree::EmailTemplates::Preview.new(store: store, key: 'spree/order_mailer/confirm_email', record_id: other.prefixed_id).call
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'says so when the store has nothing to preview with' do
    Spree::OrderGroup.where(store: store).delete_all

    expect do
      Spree::EmailTemplates::Preview.new(store: store, key: 'spree/order_group_mailer/confirm_email').call
    end.to raise_error(Spree::EmailTemplates::NoSampleRecord, /order group/)
  end
end
