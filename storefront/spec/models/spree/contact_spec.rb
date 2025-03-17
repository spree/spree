require 'spec_helper'

describe Spree::Contact, type: :model do
  let!(:store) { @default_store }
  subject { Spree::Contact.new(name: 'José', email: 'jose@email.com', message: 'Cool!', customer_support_email: 'john@example.com') }

  context 'contact form' do
    it 'valid attributes' do
      expect(subject.name).to eq('José')
      expect(subject.valid?).to eq(true)
      expect(subject.deliver).to eq(true)
    end

    it 'invalid customer support email' do
      subject.customer_support_email = nil
      expect(subject.valid?).to eq(false)
      expect(subject.errors.full_messages).to eq(["Customer support email is not there"])
    end
  end
end
