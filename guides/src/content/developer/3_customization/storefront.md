---
title: 'Storefront'
section: customization
order: 0
---

## Styling with SASS variables

Spree 4 under the hood uses [Bootstrap 4](https://getbootstrap.com/docs/4.6/getting-started/theming/) for easy theming with some additional Spree-specific [SASS variables](https://sass-lang.com/documentation/variables).

To make those changes live you need to update SCSS variable files located in your project at `app/assets/stylesheets/spree/frontend/variables/variables.scss`.

### Header

__*$header-background*__ - header background color variable with 2 examples: white and blue one. By default, this is set with a __*$primary-background*__ value but you can replace it with any other value in the variables.scss file.

![White](../../../images/developer/storefront/3.png)

![Blue](../../../images/developer/storefront/4.png)

__*$header-font-color*__- Header font color. By default set with __*$font-color*__ value but you can replace it with any other value in the variables.scss file.

![Dark grey](../../../images/developer/storefront/5.png)

![Blue](../../../images/developer/storefront/6.png)


![White](../../../images/developer/storefront/7.png)

### Footer

__*$footer-background*__ - a variable that overrides \$primary-background and allows you to change the footer color. See a white and a blue example below.

![](../../../images/developer/storefront/8.png)

![](../../../images/developer/storefront/9.png)

__*$footer-font-color*__ - a variable that overrides __*$font-color*__ and allows you to change the footer font color. See black and blue font examples below.

![](../../../images/developer/storefront/10.png)

![](../../../images/developer/storefront/11.png)

### Meganav menu

__*$meganav-background*__ - a variable that allows you to change the mega nav menu background color. By default the meganav menu is set to a __*$primary-background*__ value but you can replace it with any other value in the variables.scss file.

![](../../../images/developer/storefront/12.png)

![](../../../images/developer/storefront/13.png)

__*$meganav-font-color*__ - a font color variable in the mega nav menu. By default the mega nav font color is set to a \$font-color value but you can replace it with any other value in the variables.scss file.

![](../../../images/developer/storefront/14.png)

![](../../../images/developer/storefront/15.png)

### Background

__*$primary-background*__ - the main background color across the whole site. There are two examples below, of the white and the black backgrounds. Please note that you can also use an image as a background.

![](../../../images/developer/storefront/16.png)

![](../../../images/developer/storefront/17.png)

__*$secondary-background*__ - the second background color present across the whole site with examples attached below.

![](../../../images/developer/storefront/18.png)

![](../../../images/developer/storefront/19.png)

![](../../../images/developer/storefront/20.png)

![](../../../images/developer/storefront/21.png)

__*$font-color*__ - this variable affects all fonts on the \$primary-background. Please see two examples below.

![](../../../images/developer/storefront/22.png)

![](../../../images/developer/storefront/23.png)

__*$secondary-font-color*__ - this affects all fonts on $secondary-background. By default, it is set with a $font-color value but you can replace it with any other value in the variables.scss file.

![](../../../images/developer/storefront/24.png)

![](../../../images/developer/storefront/25.png)

### Border color

__*$global-border-style*__ - this affects the border and separator color throughout the whole site

![](../../../images/developer/storefront/26.png)

![](../../../images/developer/storefront/27.png)

![](../../../images/developer/storefront/28.png)

![](../../../images/developer/storefront/29.png)

![](../../../images/developer/storefront/30.png)

![](../../../images/developer/storefront/31.png)

![](../../../images/developer/storefront/32.png)

![](../../../images/developer/storefront/33.png)

![](../../../images/developer/storefront/34.png)

![](../../../images/developer/storefront/35.png)

### Fonts

__*$font-family*__ - this sets the font family used across your site. By default, it is in Sans Serif but you can replace it with any other value in the variables.scss file. Check out [these font families](https://websitesetup.org/web-safe-fonts-html-css/) you might use.

### Input fields

__*$input-background*__ - this allows you to set a color for all input field backgrounds across the site. See two examples of a white and a yellow backround below.

![](../../../images/developer/storefront/36.png)

![](../../../images/developer/storefront/37.png)

![](../../../images/developer/storefront/38.png)

![](../../../images/developer/storefront/39.png)

![](../../../images/developer/storefront/40.png)

![](../../../images/developer/storefront/41.png)

__*$second-global-border*__ - this allows you to set a color for all input field borders across the whole site. See an example below with red input field borders.

![](../../../images/developer/storefront/42.png)

![](../../../images/developer/storefront/43.png)

![](../../../images/developer/storefront/44.png)

### Primary color

#### Home page

__*$primary-color*__ variable changes

- The color of the **SHOP NOW** button on the main hero image

![](../../../images/developer/storefront/45.png)

- The color of the **Summer 2019** text and **READ MORE** button

![](../../../images/developer/storefront/46.png)

- The color of the **NEW COLLECTION** and **SUMMER SALE** headers inside the categories section

![](../../../images/developer/storefront/47.png)

#### Search results

__*$primary-color*__ variable changes

- The color of the **No results** icon

![](../../../images/developer/storefront/49.png)

#### Mega Menu

__*$primary-color*__ variable changes

- The color of **NEW COLLECTION** and **SUMMER SALE** headers inside the banners

![](../../../images/developer/storefront/50.png)

#### PDP

__*$primary-color*__ variable changes

- The color of the **IN STOCK** text

![](../../../images/developer/storefront/52.png)

- The color of the **ADD TO CART** button

![](../../../images/developer/storefront/53.png)

#### Cart Page

__*$primary-color*__ variable changes

- The color of the **Trash** delete icon for removing items from the cart

![](../../../images/developer/storefront/54.png)

- The color of the **CHECKOUT** button

![](../../../images/developer/storefront/55.png)

#### Cart pop-up

__*$primary-color*__ variable changes

- The color of the **CHECKOUT** and **VIEW CART** buttons

![](../../../images/developer/storefront/56.png)

#### Cart - empty

__*$primary-color*__ variable changes

- The color of the **CONTINUE SHOPPING** button

![](../../../images/developer/storefront/57.png)

- The color of the **Empty cart** icon

![](../../../images/developer/storefront/58.png)

#### Checkout - Registration Step

__*$primary-color*__ variable changes

- The color of the **LOG IN, SIGN UP** and **CONTINUE AS A GUEST** buttons

![](../../../images/developer/storefront/59.png)

![](../../../images/developer/storefront/60.png)

![](../../../images/developer/storefront/61.png)

#### Checkout - Address step

__*$primary-color*__ variable changes

- The color of the **SAVE AND CONTINUE** button (this element remains the same across the whole checkout process)

![](../../../images/developer/storefront/62.png)

- The color of the **Edit** icon

![](../../../images/developer/storefront/63.png)

#### Checkout - Payment step

__*$primary-color*__ variable changes

- The color of the **APPLY** button

![](../../../images/developer/storefront/64.png)

#### Checkout - Confirm step

__*$primary-color*__ variable changes

- The color of the **PLACE ORDER** button

![](../../../images/developer/storefront/65.png)

#### Sign-in page

__*$primary-color*__ variable changes

The color of the **LOG IN** and **SIGN UP** buttons

![](../../../images/developer/storefront/66.png)

![](../../../images/developer/storefront/67.png)

#### Sign up page

__*$primary-color*__ variable changes

- The color of the **SIGN UP** and **LOG IN** buttons

![](../../../images/developer/storefront/68.png)

![](../../../images/developer/storefront/69.png)

#### My account page

__*$primary-color*__ variable changes

- The color of the **Edit** and **Trash** icons

![](../../../images/developer/storefront/70.png)

#### Edit account page

__*$primary-color*__ variable changes

- The color of the **UPDATE** button

![](../../../images/developer/storefront/71.png)

#### Pop-ups

__*$primary-color*__ variable changes

- The color of the **CANCEL** and **OK** buttons

![](../../../images/developer/storefront/72.png)

### Secondary color

#### PLP

__*$secondary-color*__ variable changes

- The color of the chosen **color** border variant

![](../../../images/developer/storefront/73.png)

- The color of the chosen **size** border variant

![](../../../images/developer/storefront/74.png)

- The color of the chosen **length** border variant

![](../../../images/developer/storefront/75.png)

- The color of the chosen **price** border variant

![](../../../images/developer/storefront/76.png)

#### PDP

__*$secondary-color*__ variable changes

- The color of the chosen **color** border variant

![](../../../images/developer/storefront/77.png)

- The color of the chosen **size** border variant

![](../../../images/developer/storefront/78.png)

- The color of the chosen **length** border variant

![](../../../images/developer/storefront/79.png)

- The color of the chosen **image** border

![](../../../images/developer/storefront/80.png)

#### Pop-ups

__*$secondary-color*__ variable changes

- The color of the **Add to bag successfully** icon

![](../../../images/developer/storefront/81.png)

Log-in and Sign-in page

__*$secondary-color*__ variable changes

- The color of the **Remember me** checkbox

![](../../../images/developer/storefront/82.png)

- The color of the **input: focus**

![](../../../images/developer/storefront/83.png)

#### Checkout

__*$secondary-color*__ variable changes

- The color of **individual steps** (box, name step, and guideline) - this element remains the same across the whole checkout process

![](../../../images/developer/storefront/84.png)

#### Checkout - Address step

__*$secondary-color*__ variable changes

- The color of the **Use shipping address** checkbox

![](../../../images/developer/storefront/85.png)

#### Checkout - Delivery step

__*$secondary-color*__ variable changes

- The color of delivery type radio buttons

![](../../../images/developer/storefront/86.png)

#### Checkout - Payment step

__*$secondary-color*__ variable changes

- The color of payment type radio buttons

![](../../../images/developer/storefront/87.png)

- The color of payment card radio buttons

![](../../../images/developer/storefront/88.png)

#### Order confirmation page

__*$secondary-color*__ variable changes

- The color of the **successful checkmark** icon

![](../../../images/developer/storefront/89.png)

### Grid breakpoints

[Grid breakpoint variable](https://github.com/spree/spree/blob/master/frontend/app/assets/stylesheets/spree/frontend/variables/bootstrap-overrides.scss) allows you to slightly change element sizes on various devices. These changes are mostly to images and their scale ratio. Feel free to learn more from the [Bootstrap manual](https://getbootstrap.com/docs/4.0/layout/grid/), though we don’t recommend changing these values unless you really need to.

### Rounding for components

__*$enable-rounded*__ - Enable rounding for components.

Possible values: **true** or **false**

**“True” example**

![](../../../images/developer/storefront/98.png)

**“False” example**

![](../../../images/developer/storefront/99.png)

### Shadows for components

__*$enable-shadows*__ - Enable shadow for components

Possible values: **true** or **false**

### Gradient for components

__*$enable-gradients*__ - Enable gradient for components

__*$enable-gradients*__ - Enable gradient for components

## Header and footer customization

Feel free to customize header and footer elements as outlined below.

### Logo replacement

In order to replace the default Spree logo with your own [please follow these steps](https://guides.spreecommerce.org/developer/customization/view.html#switch-storefront-logo) in the Spree guides. We do recommend using 127x52 dimensions for your logo in the SVG, PNG or JPEG formats; however, if you use a higher resolution, it will scale down automatically.

### Mega menu categories

Categories visible in the Megamenu are defined in the `spree_storefront.yml`. The file is automatically copied to `config/spree_storefront.yml` in your application directory.

Make sure that these categories are also defined in the Admin panel on your site. You will find them in the `Products > Taxonomies` menu. Learn more about [categories (taxonomies and taxons)](https://guides.spreecommerce.org/user/products/taxonomies_and_taxons.html) in the Spree guides.

### Social media icons in the footer

Replace social media URLs with your own in the Spree admin panel by going to Configuration > Stores and editing (pencil icon) your store settings in the Social section.

Make sure to place the part of the URL trailing after .com/, for example:

![](../../../images/developer/storefront/100.png)

You don’t have to use any slashes.

If you leave any of the **Social** fields empty the corresponding social media icon will disappear.

After setting the values you want just click the "Update" button at the bottom of the page. Then go to
Configuration > General Settings and click the "Clear cache" button to see your updates on the frontend.

If you would like to replace the default social media icons you could replace images in this path: frontend/app/assets/images/facebook.svg <- default facebook icon. Make sure to use SVG files.

### Contact us in the footer

The footer contains a “Contact us” section with your store contact information. You can change the contents of this section in the **\_footer.html.erb** file in lines 30 to 38. The file is automatically copied to `shared/_footer.html`.erb in your application directory.

### Product categories in the footer

The footer by default contains a list of product categories in your store. Feel free to change the contents of this section in the **config/spree_storefront.yml**. The file is automatically copied to your application after running the Spree installer.

## Replacing placeholders with your images and copy

You will need to replace various promo banner placeholder images, text, and buttons with your own. These changes are necessary on the homepage and on the following promo banners (each in four sizes listed on the following pages for various devices):

- The main promo banner ("Summer Collection" and "SHOP NOW" button), as well as descriptions on all three category banners. These are the slider title ("BESTSELLERS", "TRENDING"), the mid-page promo block ("FASHION TRENDS"), and the bottom promo banners ("STREETSTYLE", "UP TO 60%")
- One category promo banner on the product listing page
- Two promo banners for each main category on the meganav menu

### Homepage placeholder slots

In the screenshot below you’ll find homepage promo banner slots with the default image placeholders indicating desktop placeholder sizes in pixels. Please note that each of these placeholders requires four images for the various devices listed below. This is just the example for desktops.

Homepage text values may be replaced in your project repository in the `/app/views/spree/home/index.html.erb`. Please note that this file will be automatically copied to your project directory after running Spree installer.

You’ll need to upload four sizes for each of these promo banners:

#### Main banner

- Main banner **1440 x 600** (desktop file)
- Main banner mobile **575 x 240** (mobile file)
- Main banner tablet landscape **992 x 413** (tablet landscape file)
- Main banner tablet portrait **768 x 320** (tablet portrait file)

#### Big category banner

- Big category banner **540 x 800** (desktop file)
- Big category banner mobile **262 x 388** (mobile file)
- Big category banner tablet landscape **470 x 696** (tablet landscape file)
- Big category banner tablet portrait **358 x 530** (tablet portrait file)

#### Upper and lower category banner

- Category banner **540 x 388** (desktop file)
- Category banner mobile **262 x 188** (mobile file)
- Category banner tablet landscape **470 x 338** (tablet landscape file)
- Category banner tablet portrait **358 x 257** (tablet portrait file)

#### Left and right promotion banners

- Promo banner **540 x 350** (desktop file)
- Promo banner mobile **542 x 351** (mobile file)
- Promo banner tablet landscape **470 x 305** (tablet landscape file)
- Promo banner tablet portrait **734 x 476** (tablet portrait file)

Please find all the [placeholder images and their size variations in this Google Drive folder](https://drive.google.com/drive/folders/1lbUMNFB2jcwpx4Jpr9uVLd_lUGw9GpVJ) for your reference.

In order to replace those placeholder images you will probably want to perform two operations:

- change the file names in the `app/views/spree/home/index.html.erb` in your project repository
- upload those images to your Spree project code repo into the `app/assets/images/homepage` folder. The files are automatically copied to your application folder after running the Spree installer, preserving the file name structure and just changing `big_category_banner` to your file name:
- `big_category_banner.jpg`
- `big_category_banner_mobile.jpg`
- `big_category_banner_tablet_landscape.jpg`
- `big_category_banner_tablet_portrait.jpg`

Such file names will be used in the srcset attribute which specifies the URL of the image to use for various screen sizes and orientations.

If you’d like to change the file names in the `app/views/spree/home/index.html.erb`, please find below the line number where new image file names can be placed.

**Main banner code lines**

Line 3:

```erb
data-src="<%= asset_path('homepage/main_banner.jpg') %>"
```

Line 4:

```erb
data-srcset="<%= image_source_set('homepage/main_banner') %>"
```

**Big category banner code lines**

Line 54:

```erb
data-src="<%= asset_path('homepage/big_category_banner.jpg') %>"
```

Line 55:

```erb
data-srcset="<%= image_source_set('homepage/big_category_banner') %>"
```

**Both category banners code lines**

Line 24:

```erb
data-src="<%= asset_path('homepage/category_banner_upper.jpg') %>"
```

Line 25:

```erb
data-srcset="<%= image_source_set('homepage/category_banner_upper) %>"
```

Line 37:

```erb
data-src="<%= asset_path('homepage/category_banner_lower.jpg') %>"
```

Line 38:

```erb
data-srcset="<%= image_source_set('homepage/category_banner_lower) %>"
```

**Both promo banners code lines**

Line 101:

```erb
data-src="<%= asset_path('homepage/promo_banner_left.jpg') %>"
```

Line 102:

```erb
data-srcset="<%= image_source_set('homepage/promo_banner_left.jpg) %>"
```

Line 121:

```erb
data-src="<%= asset_path('homepage/promo_banner_right.jpg') %>"
```

Line 122:

```erb
data-srcset="<%= image_source_set('homepage/promo_banner_right') %>"
```

### Category banner on PLP

The category product listing page (PLP) banner is displayed on the top of each product category. You need to upload just one such promo banner, sized 1110 x 300 px, through the admin panel. To do that in the Spree admin panel, go to Products > Taxonomies and edit the category for which you’d like to replace an image.

### Product images

Add a product image for each product in just one resolution (650 x 870) using the admin panel. See a full explanation of how [to edit your products](/user/products/creating_products.html#images) in the Spree guides.

The single product image will be automatically resized into multiple files and variations appropriate for different user devices will be utilized in the homepage carousels, on the product listing page (PLP), product detail page (PDP), cart pop-up, in the cart and order confirmation page.

### Mega menu

In order to modify category promo banners in the Mega nav menu (by default New Collection and Special Offers) you have to modify **spree_storefront.yml**. The file is automatically copied to your application after running the Spree installer.

## SEO recommendations

### Sitemap

We highly recommend adding a sitemap to your site. It might affect how Google bot crawls your store pages. There is an official extension called [Spree Sitemap](https://github.com/spree-contrib/spree_sitemap) for that exact purpose.

1. Per region, language or currency
2. Click the **Edit** button (indicated with a pencil icon) for the right store
3. Enter a title, keywords, and description values for the store homepage
4. Click the **Update** button at the bottom of the page

![](../../../images/developer/storefront/101.png)

To set the title, meta keywords, and description for each store **category page (PLP)**, in the admin panel:

1. Go to **Products > Taxonomies**
2. Go into the Categories list by pressing the **Edit** button (pencil icon)
3. Pick the category you’d like to edit by right-clicking (control + click on a Mac) a child in the tree to access the menu for adding, deleting or sorting a child.

![](../../../images/developer/storefront/102.png)

4. Click the **Edit** link for that category
5. Replace the default values for title, meta keywords, and description with your own
6. Click the **Update** button at the bottom of the page

![](../../../images/developer/storefront/103.png)

You’ll have to edit every category and subcategory to your liking in a similar fashion.

To set the title, meta keywords and description for each **product page (PDP)**, in the admin panel:

7. Go to **Products > Products**
8. In the product list pick the right one by pressing the **Edit** button (pencil icon)
9. While in the Details tab, scroll down and input your values for the title, meta keywords, and description
10. Click the **Update** button at the bottom of the page

![](../../../images/developer/storefront/104.png)

### Social sharing and search preview

The new Spree UX has the following social sharing features implemented:

- Facebook sharing with [Open Graph tags](https://ogp.me/) to enable an attractive page preview
- Google visibility with structured data using [Schema.org](http://schema.org/) with [JSON-DL](https://json-ld.org/)

Feel free to [test the Open Graph tags implementation](https://developers.facebook.com/tools/debug/) and the also [test the Schema.org implementation](https://search.google.com/structured-data/testing-tool/u/0/) for your store.
