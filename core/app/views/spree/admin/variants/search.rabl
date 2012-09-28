object false
child(@variants => :variants) do
  attributes :sku, :options_text, :count_on_hand, :id, :name

  child(:images => :images) do
    attributes :mini_url
  end
end
