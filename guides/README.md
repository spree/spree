# Spree Guides

This is a Spree Guides application built with [gatsby](https://www.gatsbyjs.org).

All submissions are welcome!

## Setup

You need to have Node and Yarn installed on your system, eg. macOS

```bash
brew install yarn
```

And run:

```bash
yarn install
```

That's it!

## Run locally

```bash
yarn run develop
```

Open your browser at [http://localhost:8000](http://localhost:8000)

Every change you make to files will be automatically applied!

## Dependencies Notes

`ReDoc` dependency should be hardcoded to `2.0.0-rc.12` for now. It tried to
use latest `core-js@3` import, but `Gatsby` hardcode `core-js` to `v2` now.
For more information follow this [issue](https://github.com/gatsbyjs/gatsby/issues/17136)

`gatsby-remark-component` is forked to remove annoying `console.log` messages.

`MobX` is locked because of `ReDoc`
