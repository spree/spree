shared_context 'product prototype' do
  def build_option_type_with_values(name, values)
    ot = FactoryBot.create(:option_type, name: name)
    values.each do |val|
      ot.option_values.create(name: val.downcase, presentation: val)
    end
    ot
  end

  let(:product_attributes) do
    # FactoryBot.attributes_for is un-deprecated!
    #   https://github.com/thoughtbot/factory_bot/issues/274#issuecomment-3592054
    FactoryBot.attributes_for(:base_product)
  end

  let(:prototype) do
    size = build_option_type_with_values('size', %w(Small Medium Large))
    FactoryBot.create(:prototype, name: 'Size', option_types: [size])
  end

  let(:option_values_hash) do
    hash = {}
    prototype.option_types.each do |i|
      hash[i.id.to_s] = i.option_value_ids
    end
    hash
  end
end
