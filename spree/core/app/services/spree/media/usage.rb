module Spree
  class Media
    # Answers "what breaks if I delete this file" for the media library.
    #
    # Reuse in Spree shares the underlying blob rather than copying the file, so
    # the question is about the blob, not about this row: the same file may be
    # placed on several products and picked for a category or store image, and
    # deleting one placement leaves the others working. This walks the blob's
    # attachments to list every one of them.
    #
    # Rich text embeds are found separately and only approximately — an embedded
    # image is a plain URL in stored markup, with no row tying it to the file —
    # so a description referencing this blob's key is reported as a use, and
    # markup that reaches the file some other way (a CDN alias, a copied URL from
    # another environment) is not found at all. Treat the rich text half as a
    # warning worth showing, never as proof a file is unused.
    class Usage
      prepend Spree::ServiceModule::Base

      # @param media [Spree::Media] the library row being inspected
      # @return [Array<Spree::MediaUsageReference>] every known use of its file
      def call(media:)
        blob_ids = [media.attachment_blob&.id, media.poster_blob&.id].compact
        return success([]) if blob_ids.empty?

        success(attachment_references(media, blob_ids) + rich_text_references(media, blob_ids))
      end

      private

      # Every record whose attachment points at one of these blobs, minus
      # anything belonging to another store — none of this store's business even
      # when the two happen to share a file.
      #
      # The inspected row's own placement counts: the library shows a file, not a
      # placement, so "where is this used" plainly includes the product it sits
      # on. Leaving it out reported "not used anywhere else" about a file that is
      # on a product, which is worst in the case the panel exists for — deciding
      # whether deleting it is safe.
      # One place can be reachable more than once — a video's file and poster
      # are two blobs on one row, and a category holds a file both as its image
      # slot and as the slot's library placement — hence the collapse to one
      # reference per owner, preferring the placement, which is the library's
      # own representation of the use and what the dashboard links.
      def attachment_references(media, blob_ids)
        # `record` is polymorphic, so preload it per type — reading it row by row
        # is a query each, and a widely-reused file has many rows. Media owners
        # additionally need their viewable, which build_reference reads.
        attachments = ActiveStorage::Attachment.where(blob_id: blob_ids).to_a
        owners = preloaded_owners(attachments)

        references = attachments.filter_map do |attachment|
          owner = owners[[attachment.record_type, attachment.record_id]]
          next if owner.blank?
          next unless owned_by_store?(owner, media.store_id)

          build_reference(owner, attachment.name)
        end

        references
          .group_by { |reference| [reference.owner_type, reference.owner_id] }
          .map { |_owner, group| group.find { |reference| reference.kind == 'media' } || group.first }
      end

      # @return [Hash{Array(String, Integer) => ActiveRecord::Base}] owners by [type, id]
      def preloaded_owners(attachments)
        attachments.group_by(&:record_type).each_with_object({}) do |(type, rows), owners|
          model = type.safe_constantize
          next if model.blank?

          scope = model.all
          # A media owner's own viewable is what build_reference reports.
          scope = scope.includes(:viewable) if model <= Spree::Media

          scope.where(id: rows.map(&:record_id)).each do |record|
            owners[[type, record.id]] = record
          end
        end
      end

      # Ownership must be proven, never assumed. A Spree::Store carries no
      # store_id of its own, so a blank one is not evidence the record is
      # local — treating it as such reported another tenant's logo as a use.
      def owned_by_store?(owner, store_id)
        return owner.id == store_id if owner.is_a?(Spree::Store)

        owner.try(:store_id) == store_id
      end

      def build_reference(owner, field)
        if owner.is_a?(Spree::Media)
          placement = owner.viewable
          return if placement.blank?

          Spree::MediaUsageReference.new(
            kind: 'media',
            name: display_name(placement),
            owner_type: placement.class.name,
            owner_id: placement.try(:prefixed_id),
            field: field
          )
        else
          Spree::MediaUsageReference.new(
            kind: 'attachment',
            name: display_name(owner),
            owner_type: owner.class.name,
            owner_id: owner.try(:prefixed_id),
            field: field
          )
        end
      end

      # Blob keys are opaque and unique, so a description containing one is
      # almost certainly embedding that file. Searched with LIKE, which no index
      # can serve — a deliberate cost paid on one admin screen, never in a
      # listing, and only over the store's own rows.
      #
      # Every model declaring rich text is searched. Which editors can embed a
      # file is the dashboard's decision — only the product, category and
      # collection descriptions use the picker-backed editor — so a second
      # list here would only restate that, and go stale when it changes.
      def rich_text_references(media, blob_ids)
        keys = ActiveStorage::Blob.where(id: blob_ids).pluck(:key)
        return [] if keys.empty?

        Spree::SanitizableRichText.declaring_models.flat_map do |model, attributes|
          attributes.flat_map { |attribute| rich_text_matches(media, model, attribute, keys) }
        end
      end

      def rich_text_matches(media, model, attribute, keys)
        return [] unless model.column_names.include?(attribute)

        column = model.arel_table[attribute]
        condition = keys.map { |key| column.matches("%#{key}%") }.reduce(:or)

        scope_to_store(media, model).where(condition).limit(MATCH_LIMIT).map do |record|
          Spree::MediaUsageReference.new(
            kind: 'rich_text',
            name: display_name(record),
            owner_type: record.class.name,
            owner_id: record.try(:prefixed_id),
            field: attribute
          )
        end
      rescue ActiveRecord::StatementInvalid
        # A declared rich text attribute that isn't a plain searchable column
        # (a Mobility-backed field on some adapters) should not take the whole
        # usage panel down with it.
        []
      end

      # A file belongs to one store, so its uses are that store's rows. Without
      # this the panel would report — and name — records from every other tenant.
      def scope_to_store(media, model)
        return model.all unless model.column_names.include?('store_id')

        model.where(store_id: media.store_id)
      end

      # Enough to tell a merchant "this is in use, here's where"; listing every
      # match on a catalog-wide embed would be a scan with no added meaning.
      MATCH_LIMIT = 25

      def display_name(record)
        %i[name title number email].each do |attribute|
          value = record.try(attribute)
          return value if value.present?
        end

        "#{record.class.name.demodulize} ##{record.id}"
      end
    end
  end
end
