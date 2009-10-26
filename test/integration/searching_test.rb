class SearchingTest < ActionController::IntegrationTest
  context "Search" do
    setup do
      @numbers = %w{one two three four five six}
      @taxonomy = Taxonomy.find_or_create_by_name("test_taxonomy")
      @taxons = (0..1).map{|x|
        Taxon.find_by_name("test_taxon_#{x}") ||
          Taxon.create(:name => "test_taxon_#{x}", :taxonomy_id => @taxonomy.id)
      }
      @products = (0..4).map do |x|
        pr = Factory(:product,
          :price => (x+1)*10,
          :name => "test product #{@numbers[x]}"
        )
        pr.taxons << @taxons[x%2]
        pr
      end
    end

    context "simple search" do
      should "find products based on price criteria" do
        get '/s/master_price_lt/30'
        cheap_products = Product.find(:all, :include => :master, :conditions => "variants.price < 30")

        assert_equal(cheap_products, assigns(:products))
      end

      should "find products based on more complex criteria" do
        get '/s/master_price_lt/30/name_contains/one'
        cheap_products_with_one = Product.find(:all,
          :include => :master,
          :conditions => "variants.price < 30 AND product.name LIKE '%one%'"
        )

        assert_equal(cheap_products_with_one, assigns(:products))
      end

      should "be able to be ordered" do
        get '/s/master_price_lt/30/name_contains/one/descend_by_id'
        cheap_products_with_one = Product.find(:all,
          :include => :master,
          :conditions => "variants.price < 30 AND product.name LIKE '%one%'",
          :order => "products.id DESC"
        )

        assert_equal(cheap_products_with_one, assigns(:products))
      end

      should "find products using any" do
        get '/s/name_like_any/one,two,five'
        products = %w{one two five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten

        assert_equal(products, assigns(:products))
      end

      should "find products using any and order" do
        get '/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name'
        products = %w{one two five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        assert_equal(products, assigns(:products))
      end

      should "find products using any and taxon and order" do
        get '/s/name_like_any/one,two,five/master_price_lt/30/in_taxon/test_taxon_0/descend_by_name'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        assert_equal(products, assigns(:products))
      end
    end

    context "taxon search" do
      should "find products using any" do
        get '/t/test_taxon_1/s/name_like_any/one,two,five'
        products = %w{two}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten

        assert_equal(products, assigns(:products))
      end

      should "find products using any and order" do
        get '/t/test_taxon_0/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        assert_equal(products, assigns(:products))
      end

      should "find products using any and taxon and order" do
        get '/t/test_taxon_0/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        assert_equal(products, assigns(:products))
      end
    end

    context "product group search" do
      setup do
        @pg = ProductGroup.from_url('/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name')
        @pg.name = "TestProductGroup"
        @pg.save
      end

      should "find products using named product group" do
        get '/pg/TestProductGroup'
        products = %w{one two five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        assert_equal(products, assigns(:products))
      end

      should "find products using named product group in taxon" do
        get '/t/test_taxon_0/pg/TestProductGroup'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        assert_equal(products, assigns(:products))
      end
    end

    teardown do
      @products && @products.each(&:destroy)
      Taxonomy.delete_all "name like 'test_%'"
      Taxon.delete_all "name like 'test_%'"
    end
  end
end
