# Adding Spree to an existing Rails application

### Add Spree gems to your `Gemfile`

```ruby
gem 'spree' # core and API
gem 'spree_backend' # Admin panel (optional)
gem 'spree_frontend' # Storefront (optional)
gem 'spree_emails' # transactional emails (optional)
gem 'spree_sample' # dummy data like products, taxons, etc
gem 'spree_auth_devise' # Devise integration (optional)
gem 'spree_gateway' # payment gateways eg. Stripe, Braintree (optional)
gem 'spree_i18n' # translation files (optional) 
 
# only needed for MacOS and Ruby 3+
gem 'sassc', github: 'sass/sassc-ruby', branch: 'master'
```

### Install gems

```bash
 bundle install
```

### Use the install generators to set up Spree

```
bin/rails g spree:install --user_class=Spree::User
bin/rails g spree:backend:install
bin/rails g spree:frontend:install
bin/rails g spree:auth:install
bin/rails g spree_gateway:install
```

### Installation options

By default, the installation generator (`rails g spree:install`) will run migrations as well as adding seed. This can be disabled using

```bash
bin/rails g spree:install --migrate=false --sample=false --seed=false
```

You can always perform any of these steps later by using these commands.

```bash
bin/rake railties:install:migrations
bin/rails db:migrate
bin/rails db:seed
bin/rake spree_sample:load
```

### Mounting the Spree engine

When `rails g spree:install` is run inside an application, it will install Spree, mounting the `Spree::Core::Engine` component by inserting this line automatically into `config/routes.rb`:

```ruby
mount Spree::Core::Engine, at: '/'
```

By default, all Spree routes will be available at the root of your domain. For example, if your domain is `http://localhost:3000`, Spree’s `/products` URL will be available at `http://localhost:3000/products`.

You can customize this simply by changing the `:at` specification in `config/routes.rb` to be something else. For example, if you would like Spree to be mounted at `/shop`, you can write this:

```ruby
mount Spree::Core::Engine, at: `/shop`
```

The different parts of Spree (API, Admin) will be mounted there as well, eg. `http://localhost:3000/shop/admin`.

### Use your existing authentication

[Spree Auth Devise](https://github.com/spree/spree\_auth\_devise) is the default authentication that comes with Spree but you can swap it for your own, please [follow this guide](../customization/authentication.md)

### Hello, Spree Commerce

You now have a functional Spree application after running only a few commands!

To stop the webserver, hit Ctrl-C in the terminal window where it's running. In development mode, Spree does not generally require you to stop the server; changes you make in files will be automatically picked up by the server.

#### Logging Into the Admin Panel

The next thing you'll probably want to do is to log into the admin interface. Use your browser window to navigate to [http://localhost:3000/admin](http://localhost:3000/admin). You can log in with the username `spree@example.com` and password `spree123`.

Upon successful authentication, you should see the admin screen:

Feel free to explore some of the Admin Panel features that Spree has to offer and to verify that your installation is working properly.
