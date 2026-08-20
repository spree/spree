FactoryBot.define do
  factory :seller_requirement_submission, class: Spree::SellerRequirementSubmission do
    seller
    requirement { create(:attestation_requirement, store: seller.store) }
    status { 'pending' }

    trait :accepted do
      status { 'accepted' }
      reviewed_at { Time.current }
    end

    trait :rejected do
      status { 'rejected' }
      reviewed_at { Time.current }
      review_note { 'Please send a clearer copy.' }
    end

    trait :waived do
      status { 'waived' }
      reviewed_at { Time.current }
    end

    trait :with_file do
      after(:build) do |submission|
        submission.file.attach(
          io: File.new(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'thinking-cat.jpg'
        )
      end
    end
  end
end
