# frozen_string_literal: true

shared_examples_for 'lifecycle events' do |factory: nil, event_prefix: nil|
  let(:lifecycle_factory) { factory || described_class.name.demodulize.underscore.to_sym }
  let(:lifecycle_event_prefix) { event_prefix || described_class.event_prefix }

  describe 'lifecycle events', events: true do
    describe "#{described_class.event_prefix}.created" do
      it 'publishes created event when record is created' do
        record = build(lifecycle_factory)
        expect(record).to receive(:publish_event).with("#{lifecycle_event_prefix}.created")
        allow(record).to receive(:publish_event).with(anything)

        record.save!
      end
    end

    describe "#{described_class.event_prefix}.updated" do
      it 'publishes updated event when record is updated' do
        record = create(lifecycle_factory)
        expect(record).to receive(:publish_event).with("#{lifecycle_event_prefix}.updated")
        allow(record).to receive(:publish_event).with(anything)

        # update_attribute, not update!: Spree::Shipment#update! shadows the
        # Active Record method with the legacy state-recalculation API.
        Timecop.travel(1.minute.from_now) do
          record.update_attribute(:updated_at, Time.current)
        end
      end

      it 'does not publish updated event on a bare touch' do
        record = create(lifecycle_factory)
        expect(record).not_to receive(:publish_event).with("#{lifecycle_event_prefix}.updated")
        allow(record).to receive(:publish_event).with(anything)

        record.touch
      end
    end

    describe "#{described_class.event_prefix}.deleted" do
      it 'publishes deleted event when record is deleted' do
        record = create(lifecycle_factory)
        expect(record).to receive(:publish_event).with("#{lifecycle_event_prefix}.deleted", kind_of(Hash))
        allow(record).to receive(:publish_event).with(anything)

        record.destroy!
      end
    end
  end
end
