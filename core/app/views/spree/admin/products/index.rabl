object @false
child(@collection) do
  attributes :sku, :count_on_hand, :name
  child(:variants => :variants) do
    attributes :sku, :admin_label, :count_on_hand

    child(:images => :images) do
      attributes :mini_url
    end
  end

  child(:images => :images) do
    attributes :mini_url
  end

  child(:master => :master) do
    attributes :sku, :count_on_hand
    child(:images => :images) do
      attributes :mini_url
    end
  end
end
