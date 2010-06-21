require 'test_helper'

class SearchingTest < ActionController::IntegrationTest
  context "Search" do
    setup do
      Product.delete_all
      Factory(:admin_user)
      @numbers = %w{one two three four five six}
      @taxonomy = Taxonomy.find_or_create_by_name("test_taxonomy")
      @taxons = (0..1).map{|x|
        # taxon permalink is actually test-taxon-0, I don't know why to_url replaces _ with -
        Taxon.find_by_name("test_taxon_#{x}") ||
          Taxon.create!(:name => "test_taxon_#{x}", :taxonomy_id => @taxonomy.id)
      }
      @products = (0..4).map do |x|
        pr = Factory(:product,
          :price => (x+1)*10,
          :name => "test product #{@numbers[x]}",
          :available_on => Time.now - 1.day
        )
        pr.taxons << @taxons[x%2]
        pr
      end
    end

    context "simple search" do
      should "recognize simple path" do
        assert_recognizes({
            :controller => "products",
            :action => "index",
            :product_group_query => ["master_price_lt", "30"]
        }, '/s/master_price_lt/30')
      end

      should "find products based on price criteria" do
        get '/s/master_price_lt/30'

        cheap_products = Product.find(:all, :include => :master, :conditions => "variants.price < 30")
        ## broken ## assert_equal(cheap_products, assigns(:products))
      end

      should "find products based on more complex criteria" do
        get '/s/master_price_lt/30/name_contains/one'
        cheap_products_with_one = Product.find(:all,
          :include => :master,
          :conditions => "variants.price < 30 AND products.name LIKE '%one%'"
        )

        ## broken ## assert_equal(cheap_products_with_one, assigns(:products))
      end

      should "be able to be ordered" do
        get '/s/master_price_lt/30/name_contains/one/descend_by_id'
        cheap_products_with_one = Product.find(:all,
          :include => :master,
          :conditions => "variants.price < 30 AND products.name LIKE '%one%'",
          :order => "products.id DESC"
        )

        ## broken ## assert_equal(cheap_products_with_one, assigns(:products))
      end

      should "find products using any" do
        get '/s/name_like_any/one,two,five'
        products = %w{one two five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten

        ## broken ## assert_equal(products, assigns(:products))
      end

      should "find products using any and order" do
        get '/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name'
        products = %w{one two five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}.reverse

        ## broken ## assert_equal(products.map(&:name), assigns(:products).map(&:name))
      end

      should "find products using any and taxon and order" do
        get '/s/name_like_any/one,two,five/master_price_lt/30/in_taxon/test-taxon-0/descend_by_name'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}.reverse
        ## broken ## assert_equal(products, assigns(:products))
      end
    end

    context "taxon search" do
      should "recognize taxon path correctly" do
        assert_recognizes({
            :controller => "taxons",
            :action => "show",
            :id => ['test-taxon-1'],
            :product_group_query => ["name_like_any", "one,two,three"]
        }, '/t/test-taxon-1/s/name_like_any/one,two,three')
      end

      should "find products using any" do
        get '/t/test-taxon-1/s/name_like_any/one,two,five'
        products = %w{two}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten

        ## broken ## assert_equal(products, assigns(:products))
      end

      should "find products using any and order" do
        get '/t/test-taxon-0/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        ## broken ## assert_equal(products.map(&:name), assigns(:products).map(&:name))
      end

      should "find products using any and taxon and order" do
        get '/t/test-taxon-0/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}

        ## broken ## assert_equal(products.map(&:name), assigns(:products).map(&:name))
      end
    end

    context "product group search" do
      setup do
        @pg = ProductGroup.from_url('/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name')
        @pg.name = "Test Product Group"
        @pg.save
      end

      should "recognize path corectly" do
        assert_recognizes({
            :controller => "products",
            :action => "index",
            :product_group_name => 'test-product-group'
        }, '/pg/test-product-group')

        assert_recognizes({
            :controller => "taxons",
            :action => "show",
            :id => ["test-taxon-0"],
            :product_group_name => 'test-product-group'
        }, '/t/test-taxon-0/pg/test-product-group')
      end

      should "find products using named product group" do
        get '/pg/test-product-group'
        products = %w{one two five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}.reverse

        ## broken ## assert_equal(products.map(&:name), assigns(:products).map(&:name))
      end

      should "find products using named product group in taxon" do
        get '/t/test-taxon-0/pg/test-product-group'
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}.reverse

        ## broken ## assert_equal(products.map(&:name), assigns(:products).map(&:name))
      end
    end

    teardown do
      @products && @products.each(&:destroy)
      Taxonomy.delete_all "name like 'test_%'"
      Taxon.delete_all "name like 'test_%'"
    end
  end
end
