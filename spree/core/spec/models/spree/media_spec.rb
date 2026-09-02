require 'spec_helper'

describe Spree::Media, type: :model do
  it_behaves_like 'metadata'
  it_behaves_like 'lifecycle events', event_prefix: 'media'

  describe 'named variants' do
    let(:reflection) { described_class.attachment_reflections['attachment'] }

    it 'defines preprocessed variants based on config' do
      expected_variants = Spree::Config.product_image_variant_sizes.keys + [:embed]
      expect(reflection.named_variants.keys).to match_array(expected_variants)
    end

    describe ':embed' do
      let(:named_variant) { reflection.named_variants[:embed] }

      # The gallery sizes crop to a square; an image inside a description keeps
      # whatever shape the merchant gave it.
      it 'bounds the image without cropping it' do
        expect(named_variant.transformations[:resize_to_limit]).to eq(Spree::Config.rich_text_image_size)
        expect(named_variant.transformations).not_to have_key(:resize_to_fill)
      end

      # Most files are never embedded in a description, so this one is built on
      # first use rather than on every upload.
      it 'is not preprocessed' do
        expect(named_variant.instance_variable_get(:@preprocessed)).to be_falsey
      end
    end

    Spree::Config.product_image_variant_sizes.each do |name, (width, height)|
      it "defines :#{name} variant with correct options" do
        named_variant = reflection.named_variants[name]
        expect(named_variant).to be_present
        expect(named_variant.transformations[:resize_to_fill]).to eq([width, height])
        expect(named_variant.transformations[:format]).to eq('webp')
        expect(named_variant.instance_variable_get(:@preprocessed)).to eq(true)
      end
    end
  end

  describe 'store' do
    it 'follows the product it is placed on' do
      product = create(:product)
      media = create(:image, viewable: product)

      expect(media.store).to eq(product.store)
    end

    it 'follows the variant product for a variant-pinned row' do
      variant = create(:variant)
      media = create(:asset, viewable: variant)

      expect(media.store).to eq(variant.product.store)
    end

    # A library upload has no viewable to follow, so it belongs to the store
    # whose dashboard uploaded it.
    it 'falls back to the current store when unplaced' do
      media = create(:image, viewable: nil)

      expect(media.viewable).to be_nil
      expect(media.store).to eq(Spree::Store.default)
    end

    it 'is required' do
      media = build(:image, viewable: nil)
      media.store = nil
      allow(Spree::Current).to receive(:store).and_return(nil)

      expect(media).not_to be_valid
      expect(media.errors[:store]).to be_present
    end
  end

  describe 'viewable types' do
    def media_on(type)
      build(:image, viewable: nil).tap do |media|
        media.viewable_type = type
        media.viewable_id = 1
      end
    end

    # The polymorphic column would otherwise accept any constant name, and an
    # unknown one raises on load rather than reaching this validation.
    it 'rejects a type that is not registered' do
      media = media_on('Nope::Model')

      expect(media).not_to be_valid
      expect(media.errors[:viewable_type]).to be_present
    end

    it 'accepts a type an extension registered' do
      original = Spree.media_viewable_types
      Spree.media_viewable_types += ['MyApp::Lookbook']

      media = media_on('MyApp::Lookbook')
      media.valid?

      expect(media.errors[:viewable_type]).to be_empty
    ensure
      Spree.media_viewable_types = original
    end
  end

  describe 'a row that predates the store column' do
    # Between db:migrate and spree:upgrade:backfill_media_store_ids every
    # existing row carries nil. Editing one must not fail validation.
    it 'adopts a store on its next save' do
      media = create(:image, viewable: create(:product))
      described_class.unscoped.where(id: media.id).update_all(store_id: nil)

      legacy = described_class.find(media.id)
      legacy.alt = 'Edited'

      expect(legacy.save).to be(true)
      expect(legacy.reload.store_id).to be_present
    end

    it 'still refuses moving a row between stores' do
      media = create(:image, viewable: create(:product))
      media.store = create(:store)

      expect(media.save).to be(false)
      expect(media.errors[:store]).to be_present
    end
  end

  describe 'library scopes' do
    let!(:placed) { create(:image, viewable: create(:product)) }
    let!(:unplaced) { create(:image, viewable: nil) }

    it 'separates placed rows from library uploads' do
      expect(described_class.attached).to include(placed)
      expect(described_class.attached).not_to include(unplaced)
      expect(described_class.unattached).to include(unplaced)
      expect(described_class.unattached).not_to include(placed)
    end
  end

  describe '.distinct_by_file' do
    let(:source) { create(:image, viewable: create(:product)) }

    it 'keeps one row per shared file' do
      copy = source.duplicate_for(create(:product))
      copy.save!

      result = described_class.distinct_by_file.where(id: [source.id, copy.id])

      expect(result).to contain_exactly(copy)
    end

    it 'keeps rows whose files differ' do
      other = create(:image, viewable: create(:product))

      result = described_class.distinct_by_file.where(id: [source.id, other.id])

      expect(result).to contain_exactly(source, other)
    end

    # Grouping globally let another tenant's row win, which hid the file from
    # the library that owns it entirely.
    it 'keeps a file visible in its own store when another store shares it' do
      other_store = create(:store)
      source.duplicate_for(create(:product, store: other_store)).save!

      expect(source.store.media.distinct_by_file).to include(source)
    end

    # An external video has no attachment to group by, so it can't be folded
    # into another row's file.
    it 'keeps external videos' do
      video = create(:external_video_media, viewable: create(:product))

      expect(described_class.distinct_by_file).to include(video)
    end
  end

  describe '#duplicate_for' do
    let(:source) { create(:image, viewable: create(:product), alt: 'Front view') }
    let(:target) { create(:product) }

    # The whole point of the design: placing a file elsewhere costs a row, not
    # a second copy of the file.
    it 'shares the blob rather than uploading a second copy' do
      copy = source.duplicate_for(target)

      expect { copy.save! }.not_to change(ActiveStorage::Blob, :count)
      expect(copy.attachment.blob).to eq(source.attachment.blob)
    end

    it 'copies the descriptive attributes' do
      source.update!(focal_point_x: 0.25, focal_point_y: 0.75)
      copy = source.duplicate_for(target)

      expect(copy.alt).to eq('Front view')
      expect(copy.media_type).to eq(source.media_type)
      expect(copy.focal_point).to eq({ x: 0.25, y: 0.75 })
    end

    it 'belongs to the new owner, leaving the source in place' do
      copy = source.duplicate_for(target)
      copy.save!

      expect(copy.viewable).to eq(target)
      expect(source.reload.viewable).not_to eq(target)
    end

    # Media follows the thing it is a picture of, so a copy takes the target's
    # store rather than inheriting the one the source came from.
    it 'belongs to the target product store' do
      other_store = create(:store)
      target = create(:product, store: other_store)

      copy = source.duplicate_for(target)
      copy.save!

      expect(copy.store).to eq(other_store)
    end

    it 'takes no variant links from the source' do
      product = source.product
      variant = create(:variant, product: product)
      source.update!(variant_ids: [variant.id])

      copy = source.duplicate_for(target)
      copy.save!

      expect(copy.variants).to be_empty
    end

    # Deleting one placement must not pull the file out from under the others.
    it 'leaves the file intact when one copy is destroyed' do
      copy = source.duplicate_for(target)
      copy.save!
      blob = source.attachment.blob

      perform_enqueued_jobs { copy.destroy! }

      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
      expect(source.reload.attachment).to be_attached
    end

    context 'with a video and its poster' do
      let(:source) { create(:video_media, viewable: create(:product)) }

      it 'shares the poster blob too' do
        source.poster.attach(
          io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
          filename: 'thinking-cat.jpg'
        )
        source.save!

        copy = source.duplicate_for(target)
        copy.save!

        expect(copy.poster.blob).to eq(source.poster.blob)
      end
    end
  end

  describe '#product' do
    it 'returns the product when viewable is a Variant' do
      variant = create(:variant)
      asset = create(:asset, viewable: variant)
      expect(asset.product).to eq(variant.product)
    end

    it 'returns the product when viewable is a Product' do
      product = create(:product)
      asset = create(:image, viewable: product)
      expect(asset.product).to eq(product)
    end
  end

  describe '#focal_point' do
    let(:asset) { build(:asset, focal_point_x: 0.5, focal_point_y: 0.3) }

    it 'returns hash with x and y' do
      expect(asset.focal_point).to eq({ x: 0.5, y: 0.3 })
    end

    it 'returns nil when coordinates are not set' do
      asset.focal_point_x = nil
      expect(asset.focal_point).to be_nil
    end
  end

  describe '#focal_point=' do
    let(:asset) { build(:asset) }

    it 'sets x and y from hash' do
      asset.focal_point = { x: 0.25, y: 0.75 }
      expect(asset.focal_point_x).to eq(0.25)
      expect(asset.focal_point_y).to eq(0.75)
    end

    it 'clears focal point when set to nil' do
      asset.focal_point = { x: 0.5, y: 0.5 }
      asset.focal_point = nil
      expect(asset.focal_point_x).to be_nil
      expect(asset.focal_point_y).to be_nil
    end
  end

  describe 'media_type' do
    it 'accepts valid media types' do
      %w[image video external_video].each do |type|
        asset = build(:asset, media_type: type)
        asset.valid?
        expect(asset.errors[:media_type]).to be_empty
      end
    end

    it 'rejects invalid media types' do
      asset = build(:asset, media_type: 'audio')
      expect(asset).not_to be_valid
      expect(asset.errors[:media_type]).to be_present
    end

    it 'defaults to image' do
      asset = Spree::Media.new
      expect(asset.media_type).to eq('image')
    end

    it 'defaults to image for Spree::Media subclass' do
      image = Spree::Media.new
      expect(image.media_type).to eq('image')
    end

    it 'answers a predicate per media type' do
      expect(build(:asset)).to be_image
      expect(build(:video_asset)).to be_video
      expect(build(:external_video_asset)).to be_external_video
    end
  end

  describe 'video' do
    it 'accepts an uploaded video file' do
      expect(build(:video_asset)).to be_valid
    end

    it 'requires a file, not a URL' do
      asset = build(:asset, media_type: 'video')
      asset.attachment.detach

      expect(asset).not_to be_valid
      expect(asset.errors[:attachment]).to be_present
    end

    it 'rejects a file type browsers cannot play' do
      asset = build(:asset, media_type: 'video')
      asset.attachment.attach(
        io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'text-file.txt'),
        filename: 'text-file.txt',
        content_type: 'text/plain'
      )

      expect(asset).not_to be_valid
      expect(asset.errors[:attachment]).to be_present
    end

    it 'reports as playable' do
      expect(build(:video_asset).playable_video?).to be(true)
      expect(build(:external_video_asset).playable_video?).to be(true)
      expect(build(:asset).playable_video?).to be(false)
    end
  end

  describe 'external video' do
    it 'accepts a YouTube link' do
      expect(build(:external_video_asset)).to be_valid
    end

    it 'accepts a Vimeo link' do
      expect(build(:external_video_asset, external_video_url: 'https://vimeo.com/123456789')).to be_valid
    end

    it 'requires a URL' do
      asset = build(:external_video_asset, external_video_url: nil)

      expect(asset).not_to be_valid
      expect(asset.errors[:external_video_url]).to be_present
    end

    it 'rejects a link Spree cannot embed' do
      asset = build(:external_video_asset, external_video_url: 'https://example.com/clip.mp4')

      expect(asset).not_to be_valid
      expect(asset.errors[:external_video_url]).to include('must be a YouTube or Vimeo link')
    end

    it 'needs no attachment' do
      asset = build(:external_video_asset)

      expect(asset.attachment).not_to be_attached
      expect(asset).to be_valid
    end

    it 'exposes the parsed video' do
      asset = build(:external_video_asset)

      expect(asset.external_video.provider).to eq('youtube')
      expect(asset.external_video.embed_url).to eq('https://www.youtube.com/embed/dQw4w9WgXcQ')
    end

    it 'strips whitespace around the URL' do
      asset = build(:external_video_asset, external_video_url: '  https://vimeo.com/123456789  ')

      expect(asset.external_video_url).to eq('https://vimeo.com/123456789')
    end

    it 're-parses after the URL changes' do
      asset = build(:external_video_asset)
      expect(asset.external_video.provider).to eq('youtube')

      asset.external_video_url = 'https://vimeo.com/123456789'
      expect(asset.external_video.provider).to eq('vimeo')
    end

    it 'attaches a poster only once the record saves' do
      poster = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
        filename: 'poster.jpg', content_type: 'image/jpeg'
      )
      asset = build(:external_video_asset, external_video_url: 'https://example.com/nope')
      asset.poster_signed_id = poster.signed_id

      # The record is invalid, so nothing should reach storage.
      expect(asset.save).to be(false)
      expect(asset.poster).not_to be_attached
    end

    it 'removes the poster when the signed id is blank' do
      poster = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
        filename: 'poster.jpg', content_type: 'image/jpeg'
      )
      asset = create(:external_video_asset)
      asset.update!(poster_signed_id: poster.signed_id)
      expect(asset.reload.poster).to be_attached

      asset.update!(poster_signed_id: '')

      expect(asset.reload.poster).not_to be_attached
    end

    it 'rejects a signed id it cannot resolve' do
      asset = build(:external_video_asset, poster_signed_id: 'not-a-real-signed-id')

      # A tampered id raises inside attach, which would be a 500 after the row
      # was already written — it has to fail as a validation instead.
      expect(asset).not_to be_valid
      expect(asset.errors[:poster]).to be_present
    end

    it 'rejects a poster that is not a web image' do
      asset = build(:external_video_asset)
      asset.poster.attach(
        io: File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'text-file.txt'),
        filename: 'notes.txt', content_type: 'text/plain'
      )

      expect(asset).not_to be_valid
      expect(asset.errors[:poster]).to be_present
    end

    it 'falls back to the provider thumbnail when no poster was uploaded' do
      video = build(:external_video_asset)

      expect(video.still_image).to be_nil
      expect(video.provider_still_url).to eq('https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg')
    end
  end

  describe 'counter caches with product viewable' do
    let(:product) { create(:product) }

    it 'increments media_count on product when image is created' do
      expect { create(:image, viewable: product) }
        .to change { product.reload.media_count }.by(1)
    end

    it 'decrements media_count on product when image is destroyed' do
      image = create(:image, viewable: product)
      expect { image.destroy }.to change { product.reload.media_count }.by(-1)
    end
  end

  describe 'thumbnail updates with product viewable' do
    let(:product) { create(:product) }

    it 'sets product primary_media_id when image is created' do
      image = create(:image, viewable: product)
      expect(product.reload.primary_media_id).to eq(image.id)
    end

    it 'clears product primary_media_id when image is destroyed' do
      image = create(:image, viewable: product)
      image.destroy
      expect(product.reload.primary_media_id).to be_nil
    end
  end

  # New-product uploads in the admin save assets with viewable_type set but
  # viewable_id still blank — the product doesn't exist yet. Callbacks must
  # not dereference the missing viewable.
  describe 'orphan asset (viewable_type set, viewable_id nil)' do
    it 'creates and destroys without raising' do
      asset = nil
      expect { asset = create(:image, viewable_type: 'Spree::Product', viewable_id: nil) }.not_to raise_error
      expect(asset.viewable).to be_nil
      expect { asset.destroy! }.not_to raise_error
    end
  end

  describe 'delegated methods' do
    let(:asset) { create(:image) }
    let(:attachment) { asset.attachment }

    before do
      allow(asset).to receive(:attachment).and_return(attachment)
    end

    it 'delegates :key to attachment' do
      expect(attachment).to receive(:key)
      asset.key
    end

    it 'delegates :attached? to attachment' do
      expect(attachment).to receive(:attached?)
      asset.attached?
    end

    it 'delegates :variant to attachment' do
      expect(attachment).to receive(:variant)
      asset.variant
    end

    it 'delegates :variable? to attachment' do
      expect(attachment).to receive(:variable?)
      asset.variable?
    end

    it 'delegates :blob to attachment' do
      expect(attachment).to receive(:blob)
      asset.blob
    end

    it 'delegates :filename to attachment' do
      expect(attachment).to receive(:filename)
      asset.filename
    end
  end

  describe '.with_session_uploaded_assets_uuid' do
    subject { described_class.with_session_uploaded_assets_uuid(uuid) }

    let!(:assets) { create_list(:asset, 2, session_id: uuid) }
    let!(:other_assets) { create_list(:asset, 2, session_id: SecureRandom.uuid) }

    let(:uuid) { SecureRandom.uuid }

    it 'returns assets with the given uuid' do
      expect(subject).to match_array(assets)
    end
  end

  context 'external URL' do
    before do
      create(:custom_field_definition, namespace: 'external', key: 'url', resource_type: 'Spree::Media')
    end

    describe '.with_external_url' do
      it 'returns assets with the given external URL' do
        asset = create(:asset)
        asset.set_custom_field('external.url', 'https://example.com/Example-Image-001.png')
        expect(described_class.with_external_url('https://example.com/Example-Image-001.png')).to include(asset)
      end

      it 'returns no assets if the external URL is blank' do
        expect(described_class.with_external_url(nil)).to be_empty
      end
    end

    describe '#external_url' do
      it 'returns the external URL' do
        asset = create(:asset)
        asset.set_custom_field('external.url', 'https://example.com/Example-Image-001.png')
        expect(asset.external_url).to eq('https://example.com/Example-Image-001.png')
      end

      it 'returns nil if the external URL is blank' do
        asset = create(:asset)
        expect(asset.external_url).to be_nil
      end

      # store_id is filled in at before_validation, so a row still being built
      # has none — and an imported image is given its URL before it is saved.
      it 'files the definition on the viewable store while the row is unsaved' do
        other_store = create(:store)
        product = create(:product, store: other_store)
        Spree::Current.store = nil

        media = product.images.new(viewable: product)

        expect(media.send(:custom_field_definition_store)).to eq(other_store)
      end
    end

    describe '#external_url=' do
      it 'sets the external URL' do
        asset = create(:asset)
        asset.external_url = 'https://example.com/Example-Image-001.png'
        expect(asset.external_url).to eq('https://example.com/Example-Image-001.png')
      end
    end
  end
end
