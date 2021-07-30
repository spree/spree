require 'spec_helper'

describe Spree::Api::V2::Platform::CmsSectionSerializer do
  subject { described_class.new(cms_section) }

  let(:cms_section) { create(:cms_section) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: cms_section.id.to_s,
          type: :cms_section,
          attributes: {
            name: cms_section.name,
            content: cms_section.content,
            settings: cms_section.settings,
            fit: cms_section.fit,
            destination: cms_section.destination,
            type: cms_section.type,
            position: cms_section.position,
            linked_resource_type: cms_section.linked_resource_type,
            created_at: cms_section.created_at,
            updated_at: cms_section.updated_at
          },
        }
      }
    )
  end
end
