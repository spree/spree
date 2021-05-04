const path = require("path");

const { resolve } = path;
const baseDirectoryPath = __dirname;
const srcDirectoryPath = resolve(baseDirectoryPath, "app/javascript");
const distDirectoryPath = resolve(baseDirectoryPath, "dist");

module.exports = {
  entry: resolve(srcDirectoryPath, "index.js"),
  target: "web",
  devtool: "source-map",
  mode: "production",
  module: {
    rules: [
      {
        test: /\.js$/,
        loader: "ts-loader",
        exclude: /node_modules/,
        options: {
          onlyCompileBundledFiles: true,
        },
      },
    ],
  },
  output: {
    filename: "spree_storefront.web.umd.js",
    path: distDirectoryPath,
    library: {
      type: "umd",
    },
  },
};
