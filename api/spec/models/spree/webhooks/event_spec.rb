require 'spec_helper'

describe Spree::Webhooks::Event do
  describe 'validations' do
    context 'name' do
      it 'is invalid with a blank name' do
        event = build(:event, :successful, name: '')
        expect(event.valid?).to be(false)
        expect(event.errors.messages).to eq(name: ["can't be blank"])
      end

      it 'is valid with a non-blank name' do
        event = build(:event, :successful, name: 'order.canceled')
        expect(event.valid?).to be(true)
      end
    end

    context 'susbcriber' do
      it 'is invalid without a subscriber' do
        event = build(:event, :successful, subscriber_id: nil)
        expect(event.valid?).to be(false)
        expect(event.errors.messages).to eq(subscriber: ["can't be blank", 'must exist'])
      end

      it 'is valid with a subscriber' do
        event = build(:event, :successful, subscriber: create(:subscriber))
        expect(event.valid?).to be(true)
      end
    end
  end
end
