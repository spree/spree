# Spree Guides

This is a Spree Guides application built with [Gatsby][4].

All submissions are welcome!

## Setup

You need to have Node and Yarn installed on your system, e.g. macOS.

```bash
brew install yarn
```

Go to the /guides directory inside this repository, run

```
yarn install
```

and then

```
yarn develop -- --open
```

Doing so will open a web browser window and show a live preview of the guides. Editing the guides in a text editor will automatically reload the preview.

Alternatively, to edit the guides using Docker run the following:

```
docker run -ti -p 8000:8000 -w /app -v "$(pwd):/app" -v "guides_nm:/app/node_modules" node:10 yarn install && yarn develop
```

Afterwards, go to [http://localhost:8000][3] in your browser.

## Troubleshooting

You may stumble onto an issue with file watchers when running `yarn develop`. To solve it on Linux, follow [this tutorial][1]. On macOS, try [this one][2].

## Dependencies Notes

`ReDoc` dependency should be hardcoded to `2.0.0-rc.12` for now. It tried to use latest `core-js@3` import, but `Gatsby` hardcode `core-js` to `v2` now.
For more information follow this [issue](https://github.com/gatsbyjs/gatsby/issues/17136)

`gatsby-remark-component` is forked to remove annoying `console.log` messages.

`MobX` is locked because of `ReDoc`

[1]: https://github.com/guard/listen/wiki/Increasing-the-amount-of-inotify-watchers
[2]: https://wilsonmar.github.io/maximum-limits/
[3]: http://localhost:8000
[4]: https://www.gatsbyjs.org