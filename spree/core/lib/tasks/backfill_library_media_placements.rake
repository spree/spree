namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Places existing category and collection images in the media library
      (Spree 6.0). Idempotent — reconciliation skips slots that already have
      their placement, so re-running is safe.

      Before the library, a file uploaded to a category's image slot existed
      only as an ActiveStorage attachment — in storage but invisible to the
      library and unusable anywhere else. New uploads reconcile on save; this
      walks the records that predate that.
    DESC
    task backfill_library_media_placements: :environment do
      [Spree::Category, Spree::Collection].each do |model|
        placed = 0

        model.find_each do |record|
          next unless record.library_media_slots.any? { |slot| record.public_send(slot).attached? }

          before = record.media.count
          record.sync_library_media!
          placed += record.media.count - before
        end

        puts "  Placed #{placed} #{model.name.demodulize.downcase} image(s) in the library."
      end
    end
  end
end
