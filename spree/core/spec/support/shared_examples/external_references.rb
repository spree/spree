# For a model that opts in to Spree::HasExternalReferences: its references
# are filed under the store the record belongs to. The including spec gives
# `record` (in `other_store`) and `other_store`.
shared_examples 'files external references under its store' do
  it "files the reference under the record's store" do
    reference = record.set_external_id('connector', 'KEY-1')

    expect(reference.store).to eq(other_store)
    expect(record.class.with_external_id('connector', 'KEY-1')).to contain_exactly(record)
  end
end
