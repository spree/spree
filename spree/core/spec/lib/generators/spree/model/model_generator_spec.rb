require 'spec_helper'
require 'fileutils'
require 'rails/generators'
require 'generators/spree/model/model_generator'

RSpec.describe Spree::ModelGenerator, type: :generator do
  let(:destination) { File.expand_path('../../../../../tmp/generator_test', __dir__) }

  before do
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
  end

  after do
    FileUtils.rm_rf(destination)
  end

  # `--force` skips collision check with dummy app constants.
  # `--migration` ensures Rails emits a migration even on re-runs.
  def run_generator(argv)
    described_class.start(argv + ['--force', '--migration'], destination_root: destination)

    model_path = Dir[File.join(destination, 'app/models/spree/*.rb')].first
    migration_path = Dir[File.join(destination, 'db/migrate/*.rb')].first

    {
      model: model_path && File.read(model_path),
      migration: migration_path && File.read(migration_path)
    }
  end

  describe 'model file' do
    it 'inherits from Spree.base_class by default' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:model]).to include('class Brand < Spree.base_class')
    end

    it 'lives under app/models/spree/ regardless of how the class is named' do
      run_generator(['Spree::Brand', 'name:string'])

      expect(File.exist?(File.join(destination, 'app/models/spree/brand.rb'))).to be true
    end

    it 'declares has_prefix_id derived from the snake_cased class name' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:model]).to include('has_prefix_id :brand')
    end

    it 'accepts an explicit --id-prefix override' do
      result = run_generator(['Brand', 'name:string', '--id-prefix=br'])

      expect(result[:model]).to include('has_prefix_id :br')
    end

    it 'adds acts_as_paranoid when --paranoid is set' do
      result = run_generator(['Brand', 'name:string', '--paranoid'])

      expect(result[:model]).to include('acts_as_paranoid')
    end

    it 'includes Metafields concerns when --metafields is set' do
      result = run_generator(['Brand', 'name:string', '--metafields'])

      expect(result[:model]).to include('include Spree::Metafields')
      expect(result[:model]).to include('include Spree::Metadata')
    end

    it 'declares the Ransack allowlist tuple (attributes, associations, scopes)' do
      result = run_generator(['Brand', 'name:string', 'active:boolean'])

      expect(result[:model]).to include('self.whitelisted_ransackable_attributes = %w[name active]')
      expect(result[:model]).to include('self.whitelisted_ransackable_associations = %w[]')
      expect(result[:model]).to include('self.whitelisted_ransackable_scopes = %w[]')
    end

    it 'adds presence validations for non-boolean scalar attributes' do
      result = run_generator(['Brand', 'name:string', 'active:boolean'])

      expect(result[:model]).to include('validates :name, presence: true')
      expect(result[:model]).not_to include('validates :active')
    end

    it 'adds uniqueness validation scoped to spree_base_uniqueness_scope for :uniq fields' do
      result = run_generator(['Brand', 'slug:string:uniq'])

      expect(result[:model]).to include('validates :slug, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }')
    end
  end

  describe 'belongs_to class_name resolution' do
    it 'defaults to Spree::<CamelCasedName> when the attribute name has no special handling' do
      result = run_generator(['Variant', 'product:references'])

      expect(result[:model]).to include("belongs_to :product, class_name: 'Spree::Product'")
    end

    it 'resolves to Spree.user_class for user/user_id attributes' do
      result = run_generator(['UserPreference', 'user:references'])

      expect(result[:model]).to include('belongs_to :user, class_name: "::#{Spree.user_class}"')
    end

    it 'resolves to Spree.admin_user_class for admin-user-shaped column names' do
      result = run_generator(['Audit', 'admin_user:references', 'created_by:references', 'approver:references'])

      expect(result[:model]).to include('belongs_to :admin_user, class_name: "::#{Spree.admin_user_class}"')
      expect(result[:model]).to include('belongs_to :created_by, class_name: "::#{Spree.admin_user_class}"')
      expect(result[:model]).to include('belongs_to :approver, class_name: "::#{Spree.admin_user_class}"')
    end

    it 'respects an explicit class hint on the attribute spec' do
      result = run_generator(['Note', 'category:references{TaxonCategory}'])

      expect(result[:model]).to include("belongs_to :category, class_name: 'TaxonCategory'")
    end

    it 'omits class_name and emits polymorphic: true for polymorphic references' do
      result = run_generator(['Metafield', 'resource:references{polymorphic}'])

      expect(result[:model]).to include('belongs_to :resource, polymorphic: true')
      expect(result[:model]).not_to include('class_name:')
    end
  end

  describe 'migration file' do
    it 'targets the spree_<plural> table' do
      result = run_generator(['Brand', 'name:string'])

      expect(result[:migration]).to include('create_table :spree_brands')
    end

    it 'emits null: false on every scalar column' do
      result = run_generator(['Brand', 'name:string', 'active:boolean', 'rating:decimal'])

      expect(result[:migration]).to include('t.string :name, null: false')
      expect(result[:migration]).to include('t.boolean :active, null: false')
      expect(result[:migration]).to include('t.decimal :rating, null: false')
    end

    it 'explicitly sets foreign_key: false on t.references to match Spree conventions' do
      result = run_generator(['Variant', 'product:references'])

      expect(result[:migration]).to include('t.references :product, null: false, index: true, foreign_key: false')
    end

    it 'preserves polymorphic: true on polymorphic references' do
      result = run_generator(['Metafield', 'resource:references{polymorphic}'])

      expect(result[:migration]).to include('polymorphic: true')
    end

    it 'adds a deleted_at column + index when --paranoid is set' do
      result = run_generator(['Brand', 'name:string', '--paranoid'])

      expect(result[:migration]).to include('t.datetime :deleted_at')
      expect(result[:migration]).to include('add_index :spree_brands, :deleted_at')
    end

    it 'adds a unique index for :uniq fields' do
      result = run_generator(['Brand', 'slug:string:uniq'])

      expect(result[:migration]).to include('add_index :spree_brands, :slug, unique: true')
    end

    it 'does not add a foreign key constraint anywhere' do
      result = run_generator(['Variant', 'product:references', 'name:string'])

      expect(result[:migration]).not_to match(/foreign_key:\s*true/)
      expect(result[:migration]).not_to include('add_foreign_key')
    end
  end
end
