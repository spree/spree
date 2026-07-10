require 'spec_helper'

describe Spree::Stores::SetupTasks do
  subject(:registry) { described_class.new }

  let(:store) { build(:store) }

  describe '#add' do
    it 'registers a task retrievable by key' do
      registry.add :connect_erp, position: 10, done: ->(_store) { true }

      expect(registry.exists?(:connect_erp)).to be true
      expect(registry.find(:connect_erp).key).to eq(:connect_erp)
    end

    it 'replaces a task registered under the same key' do
      registry.add :connect_erp, position: 10, done: ->(_store) { false }
      registry.add :connect_erp, position: 20, done: ->(_store) { true }

      expect(registry.tasks.size).to eq(1)
      expect(registry.find(:connect_erp).done?(store)).to be true
    end

    it 'rejects a non-callable done:' do
      expect { registry.add :broken, position: 10, done: true }.to raise_error(ArgumentError)
    end
  end

  describe '#remove' do
    it 'deletes the task' do
      registry.add :connect_erp, position: 10, done: ->(_store) { true }
      registry.remove :connect_erp

      expect(registry.exists?(:connect_erp)).to be false
    end
  end

  describe '#tasks' do
    it 'sorts by position' do
      registry.add :second, position: 20, done: ->(_store) { true }
      registry.add :first, position: 10, done: ->(_store) { true }

      expect(registry.tasks.map(&:key)).to eq(%i[first second])
    end
  end

  describe '#for' do
    it 'filters tasks by their if: condition' do
      registry.add :always, position: 10, done: ->(_store) { true }
      registry.add :never, position: 20, done: ->(_store) { true }, if: ->(_store) { false }

      expect(registry.for(store).map(&:key)).to eq(%i[always])
    end
  end

  describe 'Task' do
    it 'defaults the partial and label to the key conventions' do
      task = registry.add :connect_erp, position: 10, done: ->(_store) { true }

      expect(task.partial).to eq('spree/admin/dashboard/setup_tasks/connect_erp')
      expect(task.label_key).to eq('admin.store_setup_tasks.connect_erp')
    end

    it 'honors partial and label overrides' do
      task = registry.add :connect_erp, position: 10, done: ->(_store) { true },
                          partial: 'my_app/tasks/erp', label: 'my_app.tasks.erp'

      expect(task.partial).to eq('my_app/tasks/erp')
      expect(task.label_key).to eq('my_app.tasks.erp')
    end

    it 'evaluates done? against the given store' do
      task = registry.add :named, position: 10, done: ->(s) { s.name == 'Ready' }

      expect(task.done?(build(:store, name: 'Ready'))).to be true
      expect(task.done?(build(:store, name: 'Not yet'))).to be false
    end
  end

  describe 'default registration' do
    it 'registers the five default tasks in order on the global registry' do
      expect(Spree.store_setup_tasks.tasks.map(&:key)).to eq(
        %i[setup_payment_method add_products set_customer_support_email setup_taxes_collection setup_storefront]
      )
    end
  end
end
