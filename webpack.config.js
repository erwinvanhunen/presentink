const path = require('path');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = {
  mode: 'development',
  entry: {
    main: './src/main.ts', 
    preload: './src/preload.ts', 
    renderer: './src/renderer.ts',
    aboutpreload: './src/about-preload.ts' 
  },
  target: 'electron-main',
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: 'ts-loader',
        exclude: /node_modules/,
      },
      {
        enforce: 'pre',
        test: /\.js$/,
        loader: 'source-map-loader',
      },
    ],
  },
  resolve: {
    extensions: ['.ts', '.js'],
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, 'dist'),
  },
  devtool: 'source-map',
  plugins: [
    new CopyWebpackPlugin({
      patterns: [
        { from: 'src/distpackage.json', to: 'package.json' },
        { from: 'penimages', to: 'penimages' },
        { from: 'src/about.html', to: 'about.html' },
        { from: 'src/index.html', to: 'index.html' },
        { from: 'src/breaktimer.html', to: 'breaktimer.html' },
        { from: 'src/help.html', to: 'help.html' },
        { from: 'src/settings.html', to: 'settings.html' },
        { from: 'icon_128x128.png', to: 'icon_128x128.png' },
        { from: 'icon.icns', to: 'icon.icns' }
      ]
    })
  ]
};