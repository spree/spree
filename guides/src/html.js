/* eslint-disable react/prop-types */
import * as React from 'react'

const JS_NPM_URLS = [
  'https://unpkg.com/docsearch.js@2.4.1/dist/cdn/docsearch.min.js'
]

export default class HTML extends React.Component {
  render() {
    return (
      <html lang="en" {...this.props.htmlAttributes} className="h-100">
        <head>
          <link
            href="https://fonts.googleapis.com/css?family=Roboto+Mono:400,400i,500,500i|Source+Sans+Pro:400,400i,600,600i"
            rel="stylesheet"
          />
          <link
            rel="stylesheet"
            href="https://cdn.jsdelivr.net/npm/docsearch.js@2/dist/cdn/docsearch.min.css"
          />
          {JS_NPM_URLS.map(url => (
            <link key={url} rel="preload" href={url} as="script" />
          ))}
          <meta charSet="utf-8" />
          <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
          <meta
            name="viewport"
            content="width=device-width, initial-scale=1.0"
          />
          <link rel="icon" href="/favicon.ico" />
          {this.props.headComponents}
        </head>
        <body {...this.props.bodyAttributes} className="bg-white f5 h-100">
          <div
            className="h-100"
            id="___gatsby"
            dangerouslySetInnerHTML={{ __html: this.props.body }}
          />
          {this.props.postBodyComponents}
          {JS_NPM_URLS.map(url => (
            <script key={url} src={url} />
          ))}
        </body>
      </html>
    )
  }
}
