namespace :spree do
  namespace :metadata do
    desc "Migrate existing jsonb metadata to Metafield records"
    task migrate: :environment do
      puts "Starting metadata migration..."

      # Get all models that include Spree::Metadata
      models_with_metadata = []
      
      # Find all classes that include the Metadata concern
      ObjectSpace.each_object(Class) do |klass|
        if klass < ActiveRecord::Base && klass.included_modules.include?(Spree::Metadata)
          models_with_metadata << klass
        end
      end

      models_with_metadata.each do |model_class|
        puts "Migrating #{model_class.name}..."
        
        # Process in batches to avoid memory issues
        model_class.find_in_batches(batch_size: 100) do |batch|
          batch.each do |record|
            migrate_record_metadata(record)
          end
        end
        
        puts "Completed migrating #{model_class.name}"
      end
      
      puts "Metadata migration completed!"
    end

    desc "Rollback metadata migration - convert Metafields back to jsonb"
    task rollback: :environment do
      puts "Rolling back metadata migration..."

      # Get all models that include Spree::Metadata
      models_with_metadata = []
      
      ObjectSpace.each_object(Class) do |klass|
        if klass < ActiveRecord::Base && klass.included_modules.include?(Spree::Metadata)
          models_with_metadata << klass
        end
      end

      models_with_metadata.each do |model_class|
        puts "Rolling back #{model_class.name}..."
        
        model_class.find_in_batches(batch_size: 100) do |batch|
          batch.each do |record|
            rollback_record_metadata(record)
          end
        end
        
        puts "Completed rollback for #{model_class.name}"
      end
      
      puts "Metadata migration rollback completed!"
    end

    private

    def migrate_record_metadata(record)
      return unless record.respond_to?(:public_metadata) && record.respond_to?(:private_metadata)

      # Migrate public metadata
      if record.public_metadata.present?
        migrate_metadata_hash(record, record.public_metadata, 'public')
      end

      # Migrate private metadata
      if record.private_metadata.present?
        migrate_metadata_hash(record, record.private_metadata, 'private')
      end
    end

    def migrate_metadata_hash(record, metadata_hash, visibility)
      metadata_hash.each do |key, value|
        create_metafield(record, key.to_s, value, visibility)
      end
    end

    def create_metafield(record, key, value, visibility)
      # Determine the type based on the value
      type = case value
             when Integer
               'integer'
             when TrueClass, FalseClass
               'boolean'
             when Hash, Array
               'json'
             else
               'string'
             end

      # Check if metafield already exists
      existing = record.metafields.find_by(key: key, visibility: visibility)
      return if existing

      record.metafields.create!(
        key: key,
        value: value,
        type: type,
        visibility: visibility
      )
    rescue => e
      puts "Error creating metafield for #{record.class.name}##{record.id}: #{e.message}"
    end

    def rollback_record_metadata(record)
      return unless record.respond_to?(:metafields)

      public_metadata = {}
      private_metadata = {}

      record.public_metafields.each do |metafield|
        public_metadata[metafield.key] = metafield.typed_value
      end

      record.private_metafields.each do |metafield|
        private_metadata[metafield.key] = metafield.typed_value
      end

      # Update the record with merged metadata
      record.update_columns(
        public_metadata: record.public_metadata.merge(public_metadata),
        private_metadata: record.private_metadata.merge(private_metadata)
      )
    rescue => e
      puts "Error rolling back metadata for #{record.class.name}##{record.id}: #{e.message}"
    end
  end
end