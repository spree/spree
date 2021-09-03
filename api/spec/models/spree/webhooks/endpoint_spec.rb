require 'spec_helper'

module Spree
  describe Webhooks::Endpoint, type: :model do
    context 'after-save sets default subscriptions' do
      subject { build(:endpoint, subscriptions: subscriptions) }

      let(:default_all_subscriptions) { ['*'] }

      before do
        subject.save
        subject.reload
      end

      context 'mysql', if: ActiveRecord::Base.connection.adapter_name == 'Mysql2' do
        context 'without subscriptions when initializing an endpoint' do
          let(:subscriptions) { nil }

          it 'sets the default subscriptions' do
            expect(subject.subscriptions).to eq(default_all_subscriptions)
          end
        end

        context 'with subscriptions when initializing an endpoint' do
          subject { build(:endpoint, subscriptions: subscriptions) }

          let(:subscriptions) { ['model.event'] }

          it 'after-save does not set default subscriptions' do
            expect(subject.subscriptions).to eq(subscriptions)
          end
        end
      end

      context 'pg', if: ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' do
        let(:subscriptions) { '' }

        it 'does not execute the callback as Postgres implements default JSONB values' do
          # Although an empty string isn't a working subscription
          # what's being tested is setting default susbcriptions,
          # since MySQL does not support default values for JSON.
          expect(subject.subscriptions).to eq(subscriptions)
        end
      end
    end
  end
end
