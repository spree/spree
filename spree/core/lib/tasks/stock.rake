namespace :spree do
  namespace :stock do
    desc 'Recompute reserved and incoming counters on every stock level from their sources'
    task recount_levels: :environment do
      corrected = Spree.stock_level_recount_service.call.value

      corrected.each do |row|
        level = row[:stock_level]
        puts "  #{level.prefixed_id} (variant #{level.variant_id} @ location #{level.stock_location_id}): " \
             "reserved #{row[:reserved].join(' → ')}, incoming #{row[:incoming].join(' → ')}"
      end
      puts "  Corrected #{corrected.size} stock level(s)."
    end
  end
end
