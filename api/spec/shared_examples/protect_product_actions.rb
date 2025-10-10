shared_examples 'modifying product actions are restricted' do
  it 'cannot create a new product if not an admin' do
    api_post :create, product: { name: 'Brand new product!' }
    assert_unauthorized!
  end

  it 'cannot update a product' do
    api_put :update, id: product.to_param, product: { name: 'I hacked your store!' }
    assert_unauthorized!
  end

  it 'cannot delete a product' do
    api_delete :destroy, id: product.to_param
    assert_unauthorized!
  end
end
