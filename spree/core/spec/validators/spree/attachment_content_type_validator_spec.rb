require 'spec_helper'

RSpec.describe Spree::AttachmentContentTypeValidator do
  # A throwaway model so the validator is exercised on its own rather than
  # through whichever allowlist a real one happens to carry.
  let(:model_class) do
    Class.new(Spree::Cart) do
      def self.name = 'Spree::Cart'

      has_one_attached :document
      validates_with Spree::AttachmentContentTypeValidator,
                     attributes: [:document],
                     in: %w[application/pdf image/png application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document]
    end
  end

  let(:record) { model_class.new(store: @default_store) }

  def attach(bytes, filename:, content_type:)
    record.document.attach(io: StringIO.new(bytes.b), filename: filename, content_type: content_type)
    record
  end

  # Minimal but genuine signatures — the validator reads these, so a
  # placeholder string would prove nothing.
  let(:pdf_bytes) { "%PDF-1.7\n1 0 obj\n<<>>\nendobj\ntrailer\n" }
  let(:png_bytes) { "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR#{"\x00" * 64}" }

  describe 'a file whose bytes match the allowlist' do
    it 'accepts a PDF' do
      attach(pdf_bytes, filename: 'po.pdf', content_type: 'application/pdf').validate

      expect(record.errors[:document]).to be_empty
    end

    it 'accepts a PNG' do
      attach(png_bytes, filename: 'scan.png', content_type: 'image/png').validate

      expect(record.errors[:document]).to be_empty
    end
  end

  describe 'a file whose bytes contradict what the uploader declared' do
    # The whole point of reading the bytes: an uploader controls the filename
    # and the content type header, and neither is evidence.
    it 'rejects a shell script presented as a PDF' do
      attach("#!/bin/sh\nrm -rf /\n", filename: 'po.pdf', content_type: 'application/pdf').validate

      expect(record.errors[:document]).to include('is not a file type we accept')
    end

    it 'rejects an HTML page presented as a PDF' do
      attach('<html><script>alert(1)</script></html>', filename: 'po.pdf', content_type: 'application/pdf').validate

      expect(record.errors[:document]).to be_present
    end

    it 'rejects a Windows executable presented as a PNG' do
      attach("MZ\x90\x00\x03\x00\x00\x00#{"\x00" * 200}", filename: 'logo.png', content_type: 'image/png').validate

      expect(record.errors[:document]).to be_present
    end

    # A type that is real, but not one this attachment accepts.
    it 'rejects a GIF presented as a PNG' do
      attach("GIF89a#{"\x00" * 64}", filename: 'scan.png', content_type: 'image/png').validate

      expect(record.errors[:document]).to be_present
    end
  end

  # Office formats are zip archives whose flavour is recorded in a part that
  # can sit anywhere inside, so the extension settles which one it is — but
  # only once the bytes have proven it is an archive at all.
  describe 'an office document' do
    # A real zip archive, built by hand so the spec does not depend on a zip
    # library being in the bundle. One stored (uncompressed) entry is enough
    # for the archive to be recognised as one.
    let(:docx_bytes) do
      name = 'word/document.xml'
      body = '<?xml version="1.0"?><w:document/>'
      crc = Zlib.crc32(body)
      local = [0x04034b50, 20, 0, 0, 0, 0, crc, body.bytesize, body.bytesize, name.bytesize, 0].pack('Vv5V3v2')
      local += name + body
      central = [0x02014b50, 20, 20, 0, 0, 0, 0, crc, body.bytesize, body.bytesize,
                 name.bytesize, 0, 0, 0, 0, 0, 0].pack('Vv6V3v5V2')
      central += name
      ending = [0x06054b50, 0, 0, 1, 1, central.bytesize, local.bytesize, 0].pack('Vv4V2v')

      local + central + ending
    end

    it 'accepts one named as the office type it is' do
      attach(docx_bytes, filename: 'po.docx',
                         content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document').validate

      expect(record.errors[:document]).to be_empty
    end

    # The extension only ever narrows an archive — it cannot rescue bytes that
    # are not one.
    it 'rejects a script named with an office extension' do
      attach("#!/bin/sh\necho pwned\n", filename: 'po.docx',
                                        content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document').validate

      expect(record.errors[:document]).to be_present
    end

    # Where a legacy Word document records what it is depends on its internal
    # layout, and in a real one it routinely sits past the bytes read here. The
    # container plus the extension has to be enough, or every such file is
    # refused — which is what happens if the tie-break asks Marcel to weigh the
    # name against the bytes, since it does not record msword as a kind of OLE.
    it 'accepts a legacy Word document whose marker sits beyond the bytes read' do
      ole = +"\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1".b
      ole << ("\x00" * 20_000).b
      ole[8000, 24] = 'WordDocument'.encode('utf-16le').b

      attach(ole, filename: 'po.doc', content_type: 'application/msword').validate

      expect(record.errors[:document]).to be_empty
    end

    # An office extension on a container is a tie-break, never a passport: the
    # bytes still have to be that container.
    it 'rejects a script named with a legacy Word extension' do
      attach("#!/bin/sh\necho pwned\n", filename: 'po.doc', content_type: 'application/msword').validate

      expect(record.errors[:document]).to be_present
    end

    # A Word document identifies itself from inside its container, so it is
    # accepted on its bytes rather than on its name.
    it 'accepts a legacy Word document on its own marker' do
      ole = +"\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1".b
      ole << ("\x00" * 5000).b
      ole[1536, 24] = 'WordDocument'.encode('utf-16le').b

      attach(ole, filename: 'po.doc', content_type: 'application/msword').validate

      expect(record.errors[:document]).to be_empty
    end
  end

  describe 'when the allowlist is empty' do
    let(:model_class) do
      Class.new(Spree::Cart) do
        def self.name = 'Spree::Cart'

        has_one_attached :document
        validates_with Spree::AttachmentContentTypeValidator, attributes: [:document], in: []
      end
    end

    it 'accepts anything, since nothing was asked for' do
      attach("#!/bin/sh\n", filename: 'anything.sh', content_type: 'text/plain').validate

      expect(record.errors[:document]).to be_empty
    end
  end

  describe 'when the allowlist is a callable' do
    let(:model_class) do
      Class.new(Spree::Cart) do
        def self.name = 'Spree::Cart'

        has_one_attached :document
        validates_with Spree::AttachmentContentTypeValidator,
                       attributes: [:document], in: ->(_record) { %w[image/png] }
      end
    end

    it 'resolves it against the record' do
      attach(png_bytes, filename: 'scan.png', content_type: 'image/png').validate
      expect(record.errors[:document]).to be_empty

      other = model_class.new(store: @default_store)
      other.document.attach(io: StringIO.new(pdf_bytes.b), filename: 'po.pdf', content_type: 'application/pdf')
      other.validate

      expect(other.errors[:document]).to be_present
    end
  end

  # Files reach Active Storage in several shapes, and the bytes have to be
  # found in all of them — a shape the validator cannot read would either
  # reject good files or, worse, wave bad ones through.
  describe 'however the file was handed over' do
    it 'reads an uploaded file from a form' do
      file = Tempfile.new(['po', '.pdf'], binmode: true)
      file.write(pdf_bytes.b)
      file.rewind
      upload = ActionDispatch::Http::UploadedFile.new(
        tempfile: file, filename: 'po.pdf', type: 'application/pdf'
      )

      record.document.attach(upload)
      record.validate

      expect(record.errors[:document]).to be_empty
    end

    it 'reads a path on disk' do
      path = Rails.root.join('tmp', "validator_#{SecureRandom.hex(4)}.pdf")
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, pdf_bytes.b)

      record.document.attach(io: File.open(path, 'rb'), filename: 'po.pdf', content_type: 'application/pdf')
      record.validate

      expect(record.errors[:document]).to be_empty
    ensure
      FileUtils.rm_f(path)
    end

    # Reading the head must not consume the file: whatever runs next still has
    # to send every byte.
    it 'leaves the caller io rewound for the upload that follows' do
      io = StringIO.new(pdf_bytes.b)
      record.document.attach(io: io, filename: 'po.pdf', content_type: 'application/pdf')
      record.validate

      expect(io.pos).to eq(0)
      expect(io.read).to eq(pdf_bytes.b)
    end
  end

  # An allowlist option that never arrives would leave this accepting anything
  # on an upload path whose whole purpose is refusing hostile files, so it is
  # refused at boot rather than silently at runtime.
  describe 'when the allowlist option is missing' do
    it 'refuses to define the validation' do
      expect do
        Class.new(Spree::Cart) do
          def self.name = 'Spree::Cart'

          has_one_attached :document
          validates_with Spree::AttachmentContentTypeValidator,
                         attributes: [:document], types: %w[application/pdf]
        end
      end.to raise_error(ArgumentError, /:in or :with/)
    end
  end

  describe 'when no file is attached' do
    it 'says nothing' do
      record.validate

      expect(record.errors[:document]).to be_empty
    end
  end

  # An abandoned direct upload leaves the blob row without its bytes, as does a
  # file deleted from storage behind the record's back. The callers report the
  # former as an incomplete upload, which is more use to a buyer than being
  # told the type is wrong, so this validator stays quiet rather than blaming
  # the file type for bytes that were never delivered.
  describe 'when the stored bytes are missing' do
    it 'adds no content type error' do
      record.save!
      record.document.attach(io: StringIO.new(pdf_bytes.b), filename: 'po.pdf', content_type: 'application/pdf')
      record.save!
      record.document.blob.service.delete(record.document.blob.key)
      record.reload

      # Guards against this passing for the wrong reason: the attachment has to
      # be genuinely present for the validator to look at it at all.
      expect(record.document).to be_attached
      expect(record.errors[:document]).to be_empty

      expect { record.validate }.not_to raise_error
      expect(record.errors[:document]).to be_empty
    end
  end

  # The bug this validator replaces: the previous implementation shelled out to
  # the Unix `file` command and, on an image without it, raised its own error
  # whose internal text reached the buyer as the validation message.
  it 'does not shell out to the file command' do
    expect(Open3).not_to receive(:capture2)

    attach(pdf_bytes, filename: 'po.pdf', content_type: 'application/pdf').validate

    expect(record.errors[:document]).to be_empty
  end
end
