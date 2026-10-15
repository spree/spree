require 'spec_helper'

module ModelExtensionsSpecWarranty
  extend ActiveSupport::Concern

  included do
    has_one :warranty_variant, -> { where(is_master: false) }, class_name: 'Spree::Variant', foreign_key: :product_id
  end

  class_methods do
    def warranty_months
      24
    end
  end

  def warranty_text
    "#{name}: two years"
  end
end

RSpec.describe Spree::ModelExtensions do
  let(:registry) { described_class.new }
  # A fresh class for each example, so nothing included here reaches Spree::Product itself.
  let(:model) { Class.new(Spree::Product) }

  before { stub_const('ModelExtensionsSpecProduct', model) }

  def concern(&block)
    Module.new do
      extend ActiveSupport::Concern
      class_eval(&block)
    end.tap { |extension| stub_const("ModelExtensionsSpecConcern#{extension.object_id}", extension) }
  end

  it "adds the concern's methods, class methods and associations to the model" do
    registry.add('ModelExtensionsSpecProduct', 'ModelExtensionsSpecWarranty')
    registry.apply

    expect(model.new(name: 'Tote').warranty_text).to eq('Tote: two years')
    expect(model.warranty_months).to eq(24)
    expect(model.reflect_on_association(:warranty_variant)).to be_present
  end

  it 'waits until Spree applies them, then adds a later registration straight away' do
    registry.add('ModelExtensionsSpecProduct', 'ModelExtensionsSpecWarranty')
    expect(model).not_to include(ModelExtensionsSpecWarranty)

    registry.apply
    later = concern { def warranty_code = 'W1' }
    registry.add('ModelExtensionsSpecProduct', later.name)

    expect(model).to include(ModelExtensionsSpecWarranty, later)
  end

  it 'includes a concern once however often Spree applies them' do
    registry.add('ModelExtensionsSpecProduct', 'ModelExtensionsSpecWarranty')
    2.times { registry.apply }

    expect(model.ancestors.count(ModelExtensionsSpecWarranty)).to eq(1)
  end

  # Code reloading replaces the model class, which then needs the concern again.
  it 'adds the concern again to a reloaded model' do
    registry.add('ModelExtensionsSpecProduct', 'ModelExtensionsSpecWarranty')
    registry.apply
    reloaded = Class.new(Spree::Product)
    stub_const('ModelExtensionsSpecProduct', reloaded)

    registry.apply

    expect(reloaded).to include(ModelExtensionsSpecWarranty)
  end

  it 'resolves the configured user classes' do
    user_class = Class.new(Spree.user_class)
    allow(Spree).to receive(:user_class).and_return(user_class)
    registry.add(:user, 'ModelExtensionsSpecWarranty')
    registry.apply

    expect(user_class).to include(ModelExtensionsSpecWarranty)
    expect(registry.for(:user)).to eq(['ModelExtensionsSpecWarranty'])
  end

  it 'lists what is registered for a model' do
    registry.add('ModelExtensionsSpecProduct', 'ModelExtensionsSpecWarranty')

    expect(registry.for('ModelExtensionsSpecProduct')).to eq(['ModelExtensionsSpecWarranty'])
    expect(registry.for('Spree::Order')).to be_empty
  end

  it 'refuses a symbol that names no configured model' do
    expect { registry.add(:product, 'ModelExtensionsSpecWarranty') }.to raise_error(ArgumentError, /not a model/)
  end

  describe 'refusing to replace what the model has' do
    before { registry.apply }

    it 'refuses a method the model defines' do
      clash = concern { def purchasable? = true }

      expect { registry.add('ModelExtensionsSpecProduct', clash.name) }.to raise_error(described_class::Conflict, /purchasable\?/)
    end

    it 'refuses a method named like a column' do
      clash = concern { def slug = 'mine' }

      expect { registry.add('ModelExtensionsSpecProduct', clash.name) }.to raise_error(described_class::Conflict, /slug/)
    end

    it 'refuses a class method the model has' do
      clash = concern { class_methods { def available = none } }

      expect { registry.add('ModelExtensionsSpecProduct', clash.name) }.to raise_error(described_class::Conflict, /available/)
    end

    it 'refuses an association named like a method the model has' do
      clash = concern { included { has_one :store, class_name: 'Spree::Store' } }

      expect { registry.add('ModelExtensionsSpecProduct', clash.name) }.to raise_error(described_class::Conflict, /store/)
    end
  end
end
