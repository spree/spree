require 'spec_helper'
require 'fileutils'
require 'rails/generators'
require 'generators/spree/api_resource/api_resource_generator'

RSpec.describe Spree::ApiResourceGenerator, type: :generator do
  let(:destination) { File.expand_path('../../../../../tmp/api_resource_generator_test', __dir__) }

  before do
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
  end

  after do
    FileUtils.rm_rf(destination)
  end

  def run_generator(argv)
    described_class.start(argv + ['--skip-routes', '--skip-specs', '--force', '--migration'], destination_root: destination)

    {
      model: read_first(File.join(destination, 'app/models/spree/*.rb')),
      migration: read_first(File.join(destination, 'db/migrate/*.rb')),
      store_controller: read_at(File.join(destination, 'app/controllers/spree/api/v3/store')),
      admin_controller: read_at(File.join(destination, 'app/controllers/spree/api/v3/admin')),
      store_serializer: read_first(File.join(destination, 'app/serializers/spree/api/v3/*_serializer.rb')),
      admin_serializer: read_first(File.join(destination, 'app/serializers/spree/api/v3/admin/*_serializer.rb')),
      factory: read_first(File.join(destination, 'spec/factories/spree/*_factory.rb'))
    }
  end

  def read_first(glob)
    path = Dir[glob].find { |p| File.file?(p) }
    path && File.read(path)
  end

  def read_at(dir)
    path = Dir[File.join(dir, '*.rb')].first
    path && File.read(path)
  end

  describe 'inherits Spree::ModelGenerator behavior' do
    it 'generates the model with has_prefix_id and Spree.base_class' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:model]).to include('class Brand < Spree.base_class')
      expect(result[:model]).to include('has_prefix_id :brand')
    end

    it 'generates the migration with null: false + foreign_key: false on references' do
      result = run_generator(['Variant', 'product:references', 'name:string'])

      expect(result[:migration]).to include('t.string :name, null: false')
      expect(result[:migration]).to include('t.references :product, null: false, index: true, foreign_key: false')
    end

    it 'respects Spree.user_class for user references' do
      result = run_generator(['UserBrand', 'user:references', 'name:string'])

      expect(result[:model]).to include('belongs_to :user, class_name: "::#{Spree.user_class}"')
    end

    it 'checks model_existed_before_run against destination_root, not process cwd' do
      # Regression: the snapshot used a relative path so the gem's own
      # app/models/spree/<name>.rb was treated as existing in the user's app.
      result = run_generator(['Variant', 'product:references', 'name:string'])

      expect(result[:model]).to include('class Variant < Spree.base_class')
      expect(result[:migration]).to include('create_table :spree_variants')
    end
  end

  describe 'API controllers' do
    it 'generates a Store controller emitting a literal serializer class' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:store_controller]).to include('Spree::Api::V3::BrandSerializer')
      expect(result[:store_controller]).not_to include('Spree.api.brand_serializer')
    end

    it 'generates an Admin controller emitting a literal admin serializer class' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:admin_controller]).to include('Spree::Api::V3::Admin::BrandSerializer')
      expect(result[:admin_controller]).not_to include('Spree.api.admin_brand_serializer')
    end

    it 'skips Store generation when --no-store is set' do
      run_generator(['Brand', 'name:string', '--no-store'])

      expect(Dir[File.join(destination, 'app/controllers/spree/api/v3/store/*')]).to be_empty
    end

    it 'skips Admin generation when --no-admin is set' do
      run_generator(['Brand', 'name:string', '--no-admin'])

      expect(Dir[File.join(destination, 'app/controllers/spree/api/v3/admin/*')]).to be_empty
    end

    it 'permits flat params on the Admin controller for full CRUD' do
      result = run_generator(['Brand', 'name:string', 'active:boolean'])

      expect(result[:admin_controller]).to include('params.permit(:name, :active)')
    end

    it 'permits flat params on the Store controller only when --writable is set' do
      read_only = run_generator(['Brand', 'name:string'])
      expect(read_only[:store_controller]).not_to include('params.permit')

      FileUtils.rm_rf(destination)
      FileUtils.mkdir_p(destination)
      writable = run_generator(['Brand', 'name:string', '--writable'])
      expect(writable[:store_controller]).to include('params.permit')
    end
  end

  describe 'factory + serializers' do
    it 'generates a factory file under spec/factories/spree/ so FactoryBot.find_definitions picks it up' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:factory]).to include('factory :brand, class: Spree::Brand')
      expect(Dir[File.join(destination, 'spec/factories/spree/*_factory.rb')]).not_to be_empty
      expect(Dir[File.join(destination, 'lib/spree/testing_support/factories/*_factory.rb')]).to be_empty
    end

    it 'comments out polymorphic associations in the factory (no concrete factory to target)' do
      result = run_generator(['Tag', 'name:string', 'taggable:references{polymorphic}'])

      expect(result[:factory]).to include('# association :taggable, factory: :product')
      expect(result[:factory]).not_to match(/^\s*association :taggable$/)
    end

    it 'generates Store and Admin serializers (Admin inherits Store)' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:store_serializer]).to include('class BrandSerializer')
      expect(result[:admin_serializer]).to include('< V3::BrandSerializer')
    end

    it 'typelizes decimal columns as :string (oj_rails serializes BigDecimal as a JSON string)' do
      result = run_generator(['Brand', 'name:string', 'price:decimal', 'rank:integer', 'active:boolean'])

      expect(result[:store_serializer]).to include('typelize price: :string, rank: :number, active: :boolean')
    end

    it 'does not redeclare :id in the Store serializer (BaseSerializer already defines it as the prefixed ID)' do
      result = run_generator(['Brand', 'name:string', 'active:boolean'])

      expect(result[:store_serializer]).to match(/^\s*attributes :name, :active$/)
      expect(result[:store_serializer]).not_to include(':id,')
    end
  end
end
