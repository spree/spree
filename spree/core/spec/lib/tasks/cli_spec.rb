require 'spec_helper'
require 'rake'

describe 'spree:cli:create_api_key' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:cli:create_api_key' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'cli.rake')
  end

  before { subject.reenable }

  let!(:store) { Spree::Store.default || create(:store, default: true) }

  around do |example|
    env.each { |key, value| ENV[key] = value }
    example.run
  ensure
    env.each_key { |key| ENV.delete(key) }
  end

  context 'with KEY_TYPE=secret' do
    let(:env) { { 'NAME' => 'CI key', 'KEY_TYPE' => 'secret', 'SCOPES' => 'read_orders, write_promotions' } }

    it 'mints a secret key with the scopes from SCOPES and prints its plaintext token' do
      expect do
        expect { subject.invoke }.to output(/\Ask_/).to_stdout
      end.to change { store.api_keys.secret.count }.by(1)

      key = store.api_keys.secret.order(:created_at).last
      expect(key.name).to eq('CI key')
      expect(key.scopes).to eq(%w[read_orders write_promotions])
    end

    context 'without SCOPES' do
      let(:env) { { 'NAME' => 'CI key', 'KEY_TYPE' => 'secret' } }

      it 'fails the scope presence validation' do
        expect { subject.invoke }.to raise_error(ActiveRecord::RecordInvalid, /Scopes/)
      end
    end
  end

  context 'with KEY_TYPE=publishable' do
    let(:env) { { 'NAME' => 'Storefront', 'KEY_TYPE' => 'publishable' } }

    it 'mints a publishable key without requiring SCOPES' do
      expect do
        expect { subject.invoke }.to output(/\Apk_/).to_stdout
      end.to change { store.api_keys.publishable.count }.by(1)

      expect(store.api_keys.publishable.order(:created_at).last.scopes).to eq([])
    end
  end
end
