# frozen_string_literal: true

namespace :spree do
  namespace :prefix_ids do
    desc 'Backfill prefix_id for all existing records. Use MODEL=Spree::Order to backfill a single model. BATCH_SIZE=1000 to control batch size.'
    task backfill: :environment do
      batch_size = (ENV['BATCH_SIZE'] || 1000).to_i
      models = prefixed_id_models

      if ENV['MODEL'].present?
        model = ENV['MODEL'].constantize
        unless models.include?(model)
          puts "Error: #{ENV['MODEL']} does not have prefix_id support"
          exit 1
        end
        models = [model]
      end

      models.each do |model|
        backfill_model(model, batch_size)
      end

      puts 'Done!'
    end

    desc 'Show backfill status for all models with prefix_id'
    task status: :environment do
      models = prefixed_id_models
      total_remaining = 0
      max_name_length = models.map { |m| m.name.length }.max

      models.each do |model|
        remaining = model.unscoped.where(prefix_id: nil).count
        total_remaining += remaining
        status = remaining.zero? ? 'done' : "#{remaining} remaining"
        puts "  #{model.name.ljust(max_name_length)}  #{status}"
      end

      puts "\n  Total: #{total_remaining} remaining"
    end

    def prefixed_id_models
      Rails.application.eager_load!

      models = Spree::Base.descendants.select do |model|
        model.respond_to?(:_prefix_id_prefix) &&
          model._prefix_id_prefix.present? &&
          model.table_exists? &&
          model.column_names.include?('prefix_id')
      end

      [Spree.user_class, Spree.admin_user_class].compact.uniq.each do |user_class|
        next if models.include?(user_class)
        next unless user_class.respond_to?(:_prefix_id_prefix) && user_class._prefix_id_prefix.present?
        next unless user_class.table_exists? && user_class.column_names.include?('prefix_id')

        models << user_class
      end

      models.sort_by(&:name)
    end

    def backfill_model(model, batch_size)
      total = model.unscoped.where(prefix_id: nil).count
      if total.zero?
        puts "#{model.name}: all records already backfilled"
        return
      end

      prefix = model._prefix_id_prefix
      puts "#{model.name}: backfilling #{total} records..."
      start_time = Time.current
      processed = 0

      model.unscoped.where(prefix_id: nil).in_batches(of: batch_size) do |batch|
        ids = batch.pluck(:id)
        values = ids.map do |id|
          prefix_id = "#{prefix}_#{random_id}"
          quoted_id = model.connection.quote(id)
          quoted_prefix_id = model.connection.quote(prefix_id)
          "WHEN #{quoted_id} THEN #{quoted_prefix_id}"
        end

        sql = <<~SQL.squish
          UPDATE #{model.table_name}
          SET prefix_id = CASE id #{values.join(' ')} END
          WHERE id IN (#{ids.map { |id| model.connection.quote(id) }.join(',')})
        SQL

        model.connection.execute(sql)
        processed += ids.size
        printf "  %d / %d (%.0f%%)\r", processed, total, (processed.to_f / total * 100)
      end

      elapsed = (Time.current - start_time).round(1)
      puts "  #{model.name}: #{processed} records backfilled in #{elapsed}s"
    end

    def random_id
      alphabet = Spree::PrefixedId::ALPHABET
      length = Spree::PrefixedId::ID_LENGTH
      Array.new(length) { alphabet[SecureRandom.random_number(alphabet.length)] }.join
    end
  end
end
