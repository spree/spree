require 'spec_helper'

RSpec.describe 'seller requirement submission workflows' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :onboarding, store: store) }
  let(:staff) { create(:admin_user) }

  before { store.seller_requirements.destroy_all }

  describe Spree::SellerRequirementSubmissions::Create do
    it 'takes an attestation at the seller’s word' do
      requirement = create(:attestation_requirement, store: store)

      result = described_class.call(seller: seller, requirement: requirement)

      expect(result).to be_success
      expect(result.value).to be_accepted
      expect(requirement.satisfied?(seller)).to be true
    end

    it 'queues a manual check for whoever reviews it' do
      requirement = create(:operator_review_requirement, store: store)

      result = described_class.call(seller: seller, requirement: requirement, note: 'VAT PL123')

      expect(result.value).to be_pending
      expect(requirement.status_for(seller)).to eq('pending')
    end

    it 'refuses a submission against a requirement computed from the seller’s data' do
      requirement = create(:accept_terms_requirement, store: store)

      expect(described_class.call(seller: seller, requirement: requirement)).to be_failure
    end

    it 'refuses a document with nothing attached' do
      requirement = create(:document_requirement, store: store)

      result = described_class.call(seller: seller, requirement: requirement)

      expect(result).to be_failure
      expect(result.error.value.full_messages.join).to match(/file is required/i)
    end

    it 'refuses a file in a format a document cannot arrive as' do
      requirement = create(:document_requirement, store: store)

      result = described_class.call(
        seller: seller,
        requirement: requirement,
        file: {
          io: StringIO.new('#!/bin/sh'),
          filename: 'script.sh',
          content_type: 'application/x-sh'
        }
      )

      expect(result).to be_failure
      expect(result.error.value.full_messages.join).to match(/not a file type we accept/i)
    end

    # The header is the uploader's word for what a file is. A seller is the
    # marketplace's lower-trust writer and an operator opens these documents
    # on their own machine, so the bytes have to decide.
    it 'refuses a script wearing a PDF content type and filename' do
      requirement = create(:document_requirement, store: store)

      result = described_class.call(
        seller: seller,
        requirement: requirement,
        file: {
          io: StringIO.new("#!/bin/sh\nrm -rf /\n"),
          filename: 'certificate.pdf',
          content_type: 'application/pdf'
        }
      )

      expect(result).to be_failure
      expect(result.error.value.full_messages.join).to match(/not a file type we accept/i)
    end

    it 'refuses a document larger than the configured limit' do
      requirement = create(:document_requirement, store: store)
      allow(Spree::Config).to receive(:max_seller_document_upload_size).and_return(64)

      result = described_class.call(
        seller: seller,
        requirement: requirement,
        file: {
          io: StringIO.new("%PDF-1.4\n#{'a' * 500}"),
          filename: 'big.pdf',
          content_type: 'application/pdf'
        }
      )

      expect(result).to be_failure
      expect(result.error.value.full_messages.join).to match(/size|large/i)
    end

    context 'with a scanner registered' do
      # Registrations outlive an example, so this one is torn down rather than
      # left firing inside every test that follows.
      after { Spree.hooks.clear! }

      # The documented injection point for a virus scanner. Proven here so the
      # example in the workflow's own docs is one that runs.
      #
      # `after_create` rather than `validate`: at validate time the blob is
      # built but not yet uploaded, so a scanner has nothing in storage to
      # read. By here the bytes are there — and the submission is `pending`,
      # a state no operator acts on, so quarantining it is a status change
      # rather than a race.
      it 'lets a handler quarantine a file it has read' do
        requirement = create(:document_requirement, store: store)
        scanned = nil

        Spree.hooks.register('seller_requirement_submissions.create.after_create') do |workflow|
          scanned = workflow.submission.file.download
          workflow.submission.update!(status: 'rejected', review_note: 'Failed a virus scan.')
        end

        result = described_class.call(
          seller: seller,
          requirement: requirement,
          file: {
            io: StringIO.new("%PDF-1.4\ninfected"),
            filename: 'certificate.pdf',
            content_type: 'application/pdf'
          }
        )

        expect(result).to be_success
        expect(scanned).to include('infected')
        expect(result.value.reload).to be_rejected
      end
    end

    it 'accepts a real PDF' do
      requirement = create(:document_requirement, store: store)

      result = described_class.call(
        seller: seller,
        requirement: requirement,
        file: {
          io: StringIO.new("%PDF-1.4\ntrailer<</Root 1 0 R>>"),
          filename: 'certificate.pdf',
          content_type: 'application/pdf'
        }
      )

      expect(result).to be_success
      expect(result.value.file).to be_attached
    end

    it 'takes a scan of one' do
      requirement = create(:document_requirement, store: store)

      result = described_class.call(
        seller: seller,
        requirement: requirement,
        file: {
          io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'thinking-cat.jpg',
          content_type: 'image/jpeg'
        }
      )

      expect(result).to be_success
      expect(result.value).to be_pending
    end
  end

  describe Spree::SellerRequirementSubmissions::Accept do
    it 'settles the requirement and records who decided' do
      requirement = create(:operator_review_requirement, store: store)
      submission = create(:seller_requirement_submission, seller: seller, requirement: requirement)

      result = described_class.call(submission: submission, reviewed_by: staff, review_note: 'Checked')

      expect(result).to be_success
      expect(submission.reload).to be_accepted
      expect(submission.reviewed_by).to eq(staff)
      expect(submission.reviewed_at).to be_present
      expect(requirement.satisfied?(seller)).to be true
    end
  end

  describe Spree::SellerRequirementSubmissions::Reject do
    it 'sends it back with a reason the seller can act on' do
      requirement = create(:operator_review_requirement, store: store)
      submission = create(:seller_requirement_submission, seller: seller, requirement: requirement)

      described_class.call(submission: submission, reviewed_by: staff, review_note: 'Wrong number')

      expect(submission.reload).to be_rejected
      expect(submission.review_note).to eq('Wrong number')
      expect(requirement.status_for(seller)).to eq('rejected')
    end

    it 'refuses to reject a waiver, which would erase who granted it' do
      requirement = create(:operator_review_requirement, store: store)
      waiver = create(:seller_requirement_submission, :waived, seller: seller, requirement: requirement,
                                                               reviewed_by: staff)

      expect(described_class.call(submission: waiver, reviewed_by: staff)).to be_failure
      expect(waiver.reload).to be_waived
      expect(waiver.reviewed_by).to eq(staff)
    end
  end

  describe Spree::SellerRequirementSubmissions::Waive do
    it 'excuses one seller without pretending they did it' do
      requirement = create(:document_requirement, store: store)

      result = described_class.call(seller: seller, requirement: requirement, reviewed_by: staff,
                                    review_note: 'Verified offline')

      expect(result).to be_success
      expect(result.value).to be_waived
      expect(requirement.satisfied?(seller)).to be true
    end

    it 'leaves what the seller sent earlier readable' do
      requirement = create(:operator_review_requirement, store: store)
      earlier = create(:seller_requirement_submission, seller: seller, requirement: requirement, note: 'my note')

      described_class.call(seller: seller, requirement: requirement, reviewed_by: staff)

      expect(earlier.reload).to be_pending
      expect(seller.requirement_submissions.count).to eq(2)
    end

    it 'refuses a requirement belonging to another marketplace' do
      other = create(:document_requirement, store: create(:store))

      expect(described_class.call(seller: seller, requirement: other)).to be_failure
    end

    it 'refuses a requirement the store has switched off' do
      requirement = create(:document_requirement, store: store, active: false)

      expect(described_class.call(seller: seller, requirement: requirement)).to be_failure
    end

    # The bug this guards: a computed kind reads the seller's own data and
    # never looks at submissions, so before the base class honoured waivers
    # the operator saw a "Waived" badge next to a requirement that still
    # counted as unmet and still blocked approval.
    it 'settles a computed requirement the operator excuses the seller from' do
      requirement = create(:accept_terms_requirement, store: store)
      expect(requirement.satisfied?(seller)).to be false

      described_class.call(seller: seller, requirement: requirement, reviewed_by: staff)

      expect(requirement.satisfied?(seller.reload)).to be true
      expect(requirement.status_for(seller)).to eq('complete')
    end

    it 'counts a waived requirement as done in the seller’s progress' do
      store.seller_requirements.destroy_all
      requirement = create(:accept_terms_requirement, store: store)
      create(:billing_address_requirement, store: store)

      described_class.call(seller: seller, requirement: requirement, reviewed_by: staff)

      expect(seller.reload.onboarding_progress).to eq(done: 1, total: 2)
    end
  end
end
