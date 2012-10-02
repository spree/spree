object false
child(@variants => :variants) do
  attributes :sku, :options_text, :count_on_hand, :id, :name

  child(:images => :images) do
    attributes :mini_url
  end

  child(:option_values => :option_values) do
    child(:option_type => :option_type) do
      attributes :name, :presentation
    end
    attributes :name, :presentation
  end
end
