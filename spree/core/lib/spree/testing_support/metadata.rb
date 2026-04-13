shared_examples_for 'metadata' do |factory: described_class.name.demodulize.underscore.to_sym|
  subject { FactoryBot.create(factory) }

  it { expect(subject.has_attribute?(:metadata)).to be_truthy }

  it { expect(subject.metadata).to eq({}) }

  it { expect(subject.metadata.class).to eq(ActiveSupport::HashWithIndifferentAccess) }

  it 'reads metadata as symbolized keys' do
    string = subject.metadata[:color] = 'red'
    number = subject.metadata[:priority] = 1
    array = subject.metadata[:keywords] = ['k1', 'k2']
    hash = subject.metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(subject.metadata[:color]).to eq(string)
    expect(subject.metadata[:priority]).to eq(number)
    expect(subject.metadata[:keywords]).to eq(array)
    expect(subject.metadata[:additional_data]).to eq(hash.stringify_keys)
  end

  it 'reads metadata as string keys' do
    string = subject.metadata[:color] = 'red'
    number = subject.metadata[:priority] = 1
    array = subject.metadata[:keywords] = ['k1', 'k2']
    hash = subject.metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(subject.metadata['color']).to eq(string)
    expect(subject.metadata['priority']).to eq(number)
    expect(subject.metadata['keywords']).to eq(array)
    expect(subject.metadata['additional_data']).to eq(hash.stringify_keys)
  end

  it 'can query records by metadata properties', skip: (ENV['DB'].blank? || ENV['DB'] == 'mysql') do
    subject.metadata[:color] = 'red'
    subject.metadata[:priority] = 1
    subject.metadata[:keywords] = ['k1', 'k2']
    subject.metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(described_class.where("metadata->>'color' = ?", 'red').count).to eq(1)
    expect(described_class.where("metadata->>'priority' = ?", '1').count).to eq(1)
    expect(described_class.where("metadata -> 'keywords' ? :keyword", keyword: 'k1').count).to eq(1)
    expect(described_class.where("metadata -> 'additional_data' ->> 'size' = :size", size: 'big').count).to eq(1)
  end

  it 'can query records by metadata properties', skip: ENV['DB'] == 'postgres' do
    subject.metadata[:color] = 'red'
    subject.metadata[:priority] = 1
    subject.metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(described_class.where("JSON_EXTRACT(metadata, '$.color') = ?", 'red').count).to eq(1)
    expect(described_class.where("JSON_EXTRACT(metadata, '$.priority') = 1").count).to eq(1)
    expect(described_class.where("JSON_EXTRACT(metadata, '$.additional_data.size') = :size", size: 'big').count).to eq(1)
  end
end
