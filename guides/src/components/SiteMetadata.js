// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Helmet } from 'react-helmet'
import { graphql, StaticQuery } from 'gatsby'

/**
 * Component
 */

const SiteMetadata = ({
  pathname,
  description: pageDescription,
  title: pageTitle
}) => (
  <StaticQuery
    query={graphql`
      query SiteMetadata {
        site {
          siteMetadata {
            siteUrl
            title
            twitter
            description
          }
        }
      }
    `}
    render={({
      site: {
        siteMetadata: { siteUrl, title, twitter, description }
      }
    }) => (
      <Helmet defaultTitle={title} titleTemplate={`%s | ${title}`}>
        <html lang="en" />
        {pageTitle && <title>{pageTitle}</title>}
        <link rel="canonical" href={`${siteUrl}${pathname}`} />
        <meta name="description" content={pageDescription || description} />
        <meta name="docsearch:version" content="2.0" />
        <meta
          name="viewport"
          content="width=device-width,initial-scale=1,shrink-to-fit=no,viewport-fit=cover"
        />

        <meta property="og:url" content={siteUrl} />
        <meta property="og:type" content="website" />
        <meta property="og:locale" content="en" />
        <meta property="og:site_name" content={title} />
        <meta
          property="og:image"
          content="https://spreecommerce.org/img/wawe-with-img.png"
        />
        <meta property="og:image:width" content="512" />
        <meta property="og:image:height" content="512" />

        <meta name="twitter:card" content="summary" />
        <meta name="twitter:site" content={twitter} />
      </Helmet>
    )}
  />
)

SiteMetadata.propTypes = {
  pathname: PropTypes.string,
  description: PropTypes.string,
  title: PropTypes.string
}

export default SiteMetadata
