require 'spec_helper'
require 'spree/api/sdk_types'

# Generates types for a stand-in extension: one admin serializer of its own,
# nesting core's order, written under a temporary engine root.
RSpec.describe Spree::Api::SdkTypes do
  let(:root) { Pathname(Dir.mktmpdir('sdk-types')) }
  let(:engine) { Struct.new(:root).new(root) }
  let(:out) { root.join('types') }

  # Standalone rather than a subclass of core's base serializer, so removing
  # it afterwards takes it out of Typelizer's registry for other specs too.
  let(:serializer_source) do
    <<~RUBY
      module SdkTypesFixture
        module Admin
          class WidgetSerializer
            include Alba::Resource
            include Typelizer::DSL

            typelize id: :string, status: [:string, enum: %w[draft sent], enum_type_name: 'WidgetStatus']
            attributes :id, :status
            one :order, resource: Spree::Api::V3::Admin::OrderSerializer
          end
        end
      end
    RUBY
  end

  before do
    @configuration = Typelizer.configuration
    Typelizer.instance_variable_set(:@configuration, Typelizer::Configuration.new)
    dir = root.join('app/serializers/sdk_types_fixture/admin')
    FileUtils.mkdir_p(dir)
    File.write(dir.join('widget_serializer.rb'), serializer_source)
  end

  after do
    Typelizer.instance_variable_set(:@configuration, @configuration)
    Typelizer.base_classes.delete_if { |name| name.start_with?('SdkTypesFixture::') }
    Object.send(:remove_const, :SdkTypesFixture) if defined?(SdkTypesFixture)
    FileUtils.rm_rf(root)
  end

  def generated(path)
    File.read(out.join(path))
  end

  it "writes the extension's types for the API its serializers belong to" do
    expect(described_class.generate!(engine: engine, out: 'types')).to eq([:admin])

    widget = generated('admin/types/Widget.ts')
    expect(widget).to include('interface Widget {')
    expect(widget).to include('export type { Widget };')
    expect(widget).to match(/import type \{.*Order.*\} from '\.\.\/spree'/)
    expect(out.join('store')).not_to exist
  end

  it "takes core's types from the SDK instead of writing copies" do
    described_class.generate!(engine: engine, out: 'types')

    expect(out.join('admin/types/Order.ts')).not_to exist
    expect(generated('admin/spree.ts')).to include("export type * from '@spree/admin-sdk'")
    expect(generated('admin/spree.ts')).to include("export type * from './types'")
  end

  it 'defines its own value lists, open to values a store adds' do
    described_class.generate!(engine: engine, out: 'types')

    expect(generated('admin/types/Enums.ts')).to include(%(export type WidgetStatus = 'draft' | 'sent' | (string & {});))
    expect(Typelizer::OpenEnums.source).to eq('@spree/sdk-core')
  end

  it 'removes the types of an API that no longer has serializers' do
    stale = out.join('store/types')
    FileUtils.mkdir_p(stale)
    File.write(stale.join('Gadget.ts'), '')
    File.write(out.join('store/spree.ts'), '')

    described_class.generate!(engine: engine, out: 'types')

    expect(stale).not_to exist
    expect(out.join('store/spree.ts')).not_to exist
    expect(out.join('admin/types/Widget.ts')).to exist
  end

  it 'refuses two serializers that would generate one type' do
    dir = root.join('app/serializers/sdk_types_fixture/admin/parts')
    FileUtils.mkdir_p(dir)
    File.write(dir.join('widget_serializer.rb'), <<~RUBY)
      module SdkTypesFixture
        module Admin
          module Parts
            class WidgetSerializer
              include Alba::Resource
              include Typelizer::DSL

              attributes :id
            end
          end
        end
      end
    RUBY

    expect { described_class.generate!(engine: engine, out: 'types') }
      .to raise_error(ArgumentError, /both generate the admin type Widget/)
    expect(out.join('admin/types')).not_to exist
  end

  it "refuses a serializer that would generate a type the SDK exports" do
    File.write(root.join('app/serializers/sdk_types_fixture/admin/order_serializer.rb'), <<~RUBY)
      module SdkTypesFixture
        module Admin
          class OrderSerializer
            include Alba::Resource
            include Typelizer::DSL

            attributes :id
          end
        end
      end
    RUBY

    expect { described_class.generate!(engine: engine, out: 'types') }
      .to raise_error(ArgumentError, %r{SdkTypesFixture::Admin::OrderSerializer generates Order, which @spree/admin-sdk already exports})
  end

  it 'refuses a value list named like a generated type' do
    File.write(root.join('app/serializers/sdk_types_fixture/admin/widget_status_serializer.rb'), <<~RUBY)
      module SdkTypesFixture
        module Admin
          class WidgetStatusSerializer
            include Alba::Resource
            include Typelizer::DSL

            attributes :id
          end
        end
      end
    RUBY

    expect { described_class.generate!(engine: engine, out: 'types') }
      .to raise_error(ArgumentError, /The value list WidgetStatus is also the name of a type the admin API generates/)
  end

  it 'refuses a value list the SDK already exports' do
    source = serializer_source.sub("enum_type_name: 'WidgetStatus'", "enum_type_name: 'OrderStatus'")
    File.write(root.join('app/serializers/sdk_types_fixture/admin/widget_serializer.rb'), source)

    expect { described_class.generate!(engine: engine, out: 'types') }
      .to raise_error(ArgumentError, %r{The value list OrderStatus, which @spree/admin-sdk already exports})
  end

  it "reserves only the names the SDK exports" do
    names = described_class.send(:core_type_names, :store)

    expect(names).to include('Order')
    expect(names).not_to include('TaxCategory')
    expect(described_class.send(:core_type_names, :seller)).to include('Category')
    expect(described_class.send(:core_list_names, :admin)).to include('OrderStatus', 'CurrencyCode')
  end

  it 'sorts serializers by namespace, as core does' do
    expect(described_class.api_of(Spree::Api::V3::Admin::OrderSerializer)).to eq(:admin)
    expect(described_class.api_of(Spree::Api::V3::Seller::PayoutSerializer)).to eq(:seller)
    expect(described_class.api_of(Spree::Api::V3::OrderSerializer)).to eq(:store)
  end
end
