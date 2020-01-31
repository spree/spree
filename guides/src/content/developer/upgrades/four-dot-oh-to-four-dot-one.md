---
title: Upgrading Spree 4.0 to 4.1
section: upgrades
order: 0
hidden: true
---

This guide covers upgrading a **4.0 Spree application** to **Spree 4.1**.

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

**If you're on an older version than 4.0 please follow previous upgrade guides and perform those upgrades incrementally**, eg.

1. [upgrade 3.3 to 3.4](/developer/upgrades/three-dot-three-to-three-dot-four.html)
2. [upgrade 3.4 to 3.5](/developer/upgrades/three-dot-four-to-three-dot-five.html)
3. [upgrade 3.5 to 3.6](/developer/upgrades/three-dot-five-to-three-dot-six.html)
4. [upgrade 3.6 to 3.7](/developer/upgrades/three-dot-six-to-three-dot-seven.html)
5. [upgrade 3.7 to 4.0](/developer/upgrades/three-dot-seven-to-four-dot-oh.html)

This is the safest and recommended method.

## Update Gemfile

```ruby
gem 'spree', '~> 4.1.0.rc1'
gem 'spree_gateway', '~> 3.7'
```

## Run `bundle update`

## Install missing migrations

```bash
rails spree:install:migrations
```

## Run migrations

```bash
rails db:migrate
```

## Migrate to the new Storefront UI (optional)

Spree 4.1 comes with a completely new mobile-first ultra-fast Storefront powered by Turbolinks.

To replace your current frontend with the new Spree UI follow these steps:

1. Update Spree Auth Devise to 4.1 in your `Gemfile`

    ```ruby
    gem 'spree_auth_devise', '~> 4.1.0.rc1'
    ```

2. In your project root directory run:

    ```bash
    rails g spree:frontend:copy_storefront
    ```

    **WARNING** this will overwrite your current project templates, it's required for the new UI, so if you'll be asked by the generator what to do please choose **A** to proceed

3. Next, you  will need to copy over two files:

   * [spree_storefront.rb](https://raw.githubusercontent.com/spree/spree/master/core/lib/generators/spree/install/templates/config/initializers/spree_storefront.rb) to `config/initializers/spree_storefront.rb`
   * [spree_storefront.yml](https://raw.githubusercontent.com/spree/spree/master/core/lib/generators/spree/install/templates/config/spree_storefront.yml) to `config/spree_storefront.yml`
  
4. If you overwrote any `spree_frontend` [controllers](https://github.com/spree/spree/tree/master/frontend/app/controllers) you will need to either remove your local copies or move your custom logic to [decorators](https://guides.spreecommerce.org/developer/customization/logic.html#extending-controllers)

5. Same goes for [helpers](https://github.com/spree/spree/tree/master/frontend/app/helpers/spree)

6. You will also need to remove this line:

    ```javascript
    //= require spree/frontend/spree_auth
    ```

    from `vendor/assets/javascripts/spree/frontend.all.js` file

## Read the release notes

For information about changes contained within this release, please read the [4.1.0 Release Notes](https://guides.spreecommerce.org/release_notes/spree_4_1_0.html).

## More info

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)
