module Spree
  module Products
    # Applies the nested data a product write can carry: its variants and its
    # media. Shared by Spree::Products::Create and ::Update so both write paths
    # — and any host importing from an external system — reconcile them the
    # same way.
    #
    # Both are full replacements. The payload is the writer's whole intent, so
    # a variant absent from it is removed, and this is the operator's write
    # path: it sees and writes every seller's variants on a shared listing, so
    # nothing here narrows by seller. A seller's own path scope-fetches through
    # `current_seller` at the controller
    # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 10) and never
    # reaches here with a payload naming another seller's rows.
    module NestedAttributes
      extend ActiveSupport::Concern

      private

      # @param product [Spree::Product]
      # @param variants_params [Array<Hash>, nil] nil leaves variants alone
      # @return [void]
      def apply_variants(product, variants_params)
        return if variants_params.blank?

        variant_ids_in_payload = []
        mutated = false

        variants_params.each do |raw|
          variant_data = raw.to_h.with_indifferent_access
          variant_id = variant_data.delete(:id)

          variant = write_variant(product, variant_data, variant_id, variant_ids_in_payload)

          variant_ids_in_payload << variant.id
          mutated = true
        end

        if variant_ids_in_payload.any?
          removed = product.variants.where.not(id: variant_ids_in_payload).destroy_all
          mutated ||= removed.any?
        end

        sync_variant_state(product) if mutated
      end

      # Delegates to the variant workflows rather than assigning and saving
      # here, so a variant written as part of a product payload passes the
      # same gate — and the same :validate handlers — as one written through
      # the variants endpoint.
      def write_variant(product, variant_data, variant_id, consumed_ids)
        existing = resolve_variant(product, variant_data, variant_id, consumed_ids)

        result =
          if existing
            Spree.variant_update_workflow.call(variant: existing, attributes: variant_data)
          else
            Spree.variant_create_workflow.call(product: product, attributes: variant_data)
          end

        # A rejection inside the nested write is the product write failing;
        # raising rolls the whole payload back rather than leaving a product
        # with half its variants.
        raise ActiveRecord::RecordInvalid, result.value if result.failure?

        result.value
      end

      # The variant this entry names, or nil when it describes a new one.
      def resolve_variant(product, variant_data, variant_id, consumed_ids)
        return product.variants.find_by_param!(variant_id) if variant_id.present?

        # An id-less, option-less entry targets the product's existing
        # option-less default variant — the simple-product case. Updating it in
        # place keeps its id, the order lines referencing it, and any prices or
        # stock the payload does not mention.
        # nil means "a new variant", which Spree::Variants::Create builds.
        reuse_default_variant?(product, variant_data, consumed_ids) ? product.default_variant : nil
      end

      def reuse_default_variant?(product, variant_data, consumed_ids)
        variant_data[:options].blank? &&
          variant_data[:option_value_variants_attributes].blank? &&
          product.default_variant.present? &&
          product.default_variant.option_values.empty? &&
          consumed_ids.exclude?(product.default_variant.id)
      end

      # variant_count is bumped by a counter cache in a Variant callback and the
      # default_variant association is cached, so both are stale after writing
      # variants out of band. Without this a product serialized in the same
      # request reports the count and price it had before the write.
      def sync_variant_state(product)
        product[:variant_count] = product.class.where(id: product.id).pick(:variant_count)
        product.variants.reset
        product.association(:default_variant).reset
      end

      # Media entries come in five kinds: an `id` patches an existing asset, a
      # `signed_id` attaches an already-uploaded blob, a `source_media_id`
      # places a file already in the library, an `external_url` hands the fetch
      # to a background job, and an external video carries a URL instead of a
      # file. Omitting an entry leaves it alone — removal is the dedicated
      # DELETE endpoint's job, so a form shipping stale state cannot destroy a
      # merchant's images.
      #
      # @param product [Spree::Product]
      # @param media_params [Array<Hash>, nil]
      # @return [void]
      def apply_media(product, media_params)
        return if media_params.blank?

        media_params.each do |raw|
          attrs = (raw.respond_to?(:to_h) ? raw.to_h : raw).with_indifferent_access

          # Every way of getting at a file comes off first, so whichever branch
          # runs is left with attributes alone. Pulling one out inside its own
          # branch leaves the others in the hash, and an entry carrying two of
          # them reaches assign_attributes with a key no column matches.
          asset_id = attrs.delete(:id)
          source_media_id = attrs.delete(:source_media_id)
          external_url = attrs.delete(:external_url)
          signed_id = attrs.delete(:signed_id)

          if asset_id.present?
            asset = product.media.find_by_param(asset_id) || next
            asset.update!(attrs)
            next
          end

          next place_from_library(product, source_media_id, attrs) if source_media_id.present?
          next enqueue_media_download(product, external_url, attrs) if external_url.present?
          next if signed_id.blank? && attrs[:media_type] != 'external_video'

          asset = product.media.build(attrs)
          asset.attachment.attach(signed_id) if signed_id.present?
          asset.save!
        end
      end

      # Places a file already in the store's library onto this product. The new
      # row shares the source's blob rather than copying the file.
      #
      # The source is looked up through the product's own store, so an id from
      # another store is ignored rather than copying a file across the tenancy
      # boundary — the same rule the media endpoint enforces with a 404.
      #
      # @param product [Spree::Product]
      # @param source_media_id [String] prefixed or raw id of the library row
      # @param attrs [Hash] attributes for the new placement
      # @return [void]
      def place_from_library(product, source_media_id, attrs)
        source = product.store&.media&.find_by_param(source_media_id)
        return if source.blank?

        copy = source.duplicate_for(product)
        copy.assign_attributes(attrs)
        copy.save!
      end

      # Downloading is a job rather than a step: it reaches out over the
      # network, and the job already owns the parts that makes necessary —
      # SSRF filtering, a size cap, and skipping a URL this product has
      # already fetched.
      #
      # Enqueued after the transaction commits, because the job loads the
      # product by id: a worker picking it up mid-transaction would not find
      # a product that is not visible to its connection yet.
      #
      # The asset is always attached to the product so one file is not
      # downloaded once per variant; `variant_id` links the resulting asset to
      # a variant afterwards.
      def enqueue_media_download(product, external_url, attrs)
        arguments = [
          product.id,
          'Spree::Product',
          external_url,
          attrs[:external_id],
          attrs[:position],
          attrs[:variant_id]
        ]

        ActiveRecord.after_all_transactions_commit do
          Spree::Images::SaveFromUrlJob.perform_later(*arguments)
        end
      end

      # Attaches downloadable files a product write ships inline, so a new
      # product can carry its digital files in the same request. Create-only,
      # additive: each entry carries a `signed_id` (an uploaded file) or a
      # `provider_type` (a provider-backed asset), and attaches to the default
      # variant unless `variant_id` names another. Edits and deletes go through
      # the nested digital_assets endpoints.
      #
      # @param product [Spree::Product]
      # @param digital_assets_params [Array<Hash>, nil]
      # @return [void]
      def apply_digital_assets(product, digital_assets_params)
        return if digital_assets_params.blank?

        digital_assets_params.each do |raw|
          attrs = (raw.respond_to?(:to_h) ? raw.to_h : raw).with_indifferent_access

          signed_id = attrs.delete(:signed_id)
          variant_id = attrs.delete(:variant_id)
          target = variant_id.present? ? product.variants.find_by_param!(variant_id) : product.default_variant
          next unless target

          asset = target.digital_assets.build(attrs.except(:id))
          if signed_id.present?
            # Attaching never moves a blob between storage services, so a file
            # uploaded to the public bucket would stay publicly readable. Refuse
            # it rather than attaching it wrongly.
            blob = ActiveStorage::Blob.find_signed(signed_id)
            unless blob && blob.service_name.to_s == Spree.private_storage_service_name.to_s
              raise ActiveRecord::RecordInvalid.new(asset)
            end

            asset.attachment.attach(signed_id)
          end
          asset.save!
        end
      end
    end
  end
end
