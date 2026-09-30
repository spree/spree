require 'spec_helper'

RSpec.shared_examples 'a host of the 6.0 purchase renames' do
  before { allow(Spree::Deprecation).to receive(:warn) }

  Spree::Purchase::DeprecatedAliases::RENAMED_ATTRIBUTES.each do |legacy_name, current_name|
    describe "##{legacy_name}" do
      it "reads and writes ##{current_name} with a warning" do
        value = current_name == :customer_note ? 'Leave at the door' : 7

        record.public_send(:"#{legacy_name}=", value)

        expect(record.public_send(current_name)).to eq(value)
        expect(record.public_send(legacy_name)).to eq(value)
        expect(Spree::Deprecation).to have_received(:warn).with(/#{record.class.name}##{legacy_name}= is deprecated.*##{current_name}=/)
        expect(Spree::Deprecation).to have_received(:warn).with(/#{record.class.name}##{legacy_name} is deprecated.*##{current_name} instead/)
      end
    end
  end

  it 'resolves a renamed column in queries' do
    record.update!(discount_total: -5)

    expect(record.class.where(promo_total: -5)).to include(record)
  end

  it 'forwards renamed methods to their replacement with a warning' do
    record.discount_total = -5

    expect(record.display_promo_total).to eq(record.display_discount_total)
    expect(Spree::Deprecation).to have_received(:warn).with(/display_promo_total is deprecated.*#display_discount_total/)
  end

  it 'forwards arguments of renamed methods' do
    customer = build(:user)
    allow(record).to receive(:associate_customer!)

    record.associate_user!(customer, false)

    expect(record).to have_received(:associate_customer!).with(customer, false)
  end

  it 'answers the legacy payment method readers with #payment_methods' do
    allow(record).to receive(:payment_methods).and_return([:payment_method])

    expect(record.available_payment_methods(record.store)).to eq([:payment_method])
    expect(record.collect_frontend_payment_methods).to eq([:payment_method])
    expect(Spree::Deprecation).to have_received(:warn).with(/available_payment_methods is deprecated.*#payment_methods/)
  end

  it 'keeps the user alias for the customer' do
    customer = create(:user)

    record.user = customer

    expect(record.customer).to eq(customer)
    expect(record.user_id).to eq(customer.id)
    expect(Spree::Deprecation).to have_received(:warn).with(/#{record.class.name}#user= is deprecated/)
  end
end

RSpec.describe Spree::Purchase::DeprecatedAliases do
  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: @default_store) }

    it_behaves_like 'a host of the 6.0 purchase renames'
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order, store: @default_store) }

    it_behaves_like 'a host of the 6.0 purchase renames'
  end
end
