object @false
child(@collection => :products) do
  attributes :sku, :count_on_hand, :name, :id
  child(:variants => :variants) do
    attributes :sku, :options_text, :count_on_hand, :id

    child(:images => :images) do
      attributes :mini_url
    end
  end

  child(:images => :images) do
    attributes :mini_url
  end

  child(:master => :master) do
    attributes :sku, :count_on_hand, :id
    child(:images => :images) do
      attributes :mini_url
    end
  end
end
