const { resolve } = require("path");
const VueLoaderPlugin = require("vue-loader/lib/plugin");
const TerserWebpackPlugin = require("terser-webpack-plugin");
const OptimizeCssAssetsWebpackPlugin = require("optimize-css-assets-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");

/**
 * Enabling `DEV` will enable debug build procedures for the UI
 *
 * WARNING: DO NOT enable this unless you are truly developing
 * the resource. This will dramatically increase bundle sizes.
 */
const DEV = process.env.NODE_ENV !== 'production';

module.exports = {
  mode: DEV ? "development" : "production",
  entry: {
    index: "./src/main.js",
  },
  output: {
    path: resolve(__dirname, "dist"),
    filename: "bundle.js",
  },
  resolve: {
    extensions: [".jsx", ".js", ".ts", ".tsx"],
  },
  module: {
    rules: [
      {
        test: /\.vue$/,
        loader: "vue-loader",
        exclude: /node_modules/,
      },
      {
        test: /\.(js|mjs|cjs)$/,
        // exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            presets: [
              require('@babel/preset-env'),
            ],
            plugins: [
              require('@babel/plugin-transform-optional-chaining'),
            ]
          },
        },
      },
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, "css-loader"],
      },
      {
        test: /\.(ttf|otf)$/,
        use: {
          loader: "file-loader",
          options: { outputPath: "fonts" },
        },
      },
      {
        test: /\.(png|jpe?g|)$/,
        use: {
          loader: "file-loader",
          options: { outputPath: "images" },
        },
      },
    ],
  },
  devtool: DEV ? "eval-source-map" : "cheap-source-map",
  optimization: {
    minimize: !DEV,
    minimizer: [
      new TerserWebpackPlugin({}),
      new OptimizeCssAssetsWebpackPlugin({}),
    ],
  },
  plugins: [
    new VueLoaderPlugin(),
    new MiniCssExtractPlugin({
      filename: "bundle.css",
    }),
    new HtmlWebpackPlugin({
      filename: "ui.html",
      template: resolve(__dirname, "src/index.html"),
    }),
  ],
};
