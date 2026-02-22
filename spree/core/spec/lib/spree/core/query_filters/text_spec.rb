require 'spec_helper'

module Spree
  module Core
    describe QueryFilters::Text do
      let(:subject) do
        described_class.new(attribute: Spree::DummyModel.arel_table[:name])
      end

      let!(:dummy1) { Spree::DummyModel.create(name: 'TestName', position: 3) }
      let!(:dummy2) { Spree::DummyModel.create(name: 'Test', position: 10) }
      let!(:dummy3) { Spree::DummyModel.create(name: 'Something', position: 4) }
      let(:scope) { Spree::DummyModel.all }

      context 'with eq matcher' do
        let(:filter) do
          {
            position: { eq: 'TestName' }
          }
        end

        it 'returns correct dummies' do
          result = subject.call(scope: scope, filter: filter[:position])
          expect(result).to include(dummy1)
          expect(result).not_to include(dummy2, dummy3)
        end
      end

      context 'with contains matcher' do
        let(:filter) do
          {
            position: { contains: 'Test' }
          }
        end

        it 'returns correct dummies' do
          result = subject.call(scope: scope, filter: filter[:position])
          expect(result).to include(dummy1, dummy2)
          expect(result).not_to include(dummy3)
        end
      end
    end
  end
end
