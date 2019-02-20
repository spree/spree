import * as React from 'react'
import PropTypes from 'prop-types'
import { OutboundLink } from 'gatsby-plugin-google-gtag'

const ExternalLink = ({ url, children }) => (
  <OutboundLink href={url} rel="nofollow" target="_blank">
    {children}
  </OutboundLink>
)

ExternalLink.propTypes = {
  url: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired
}

export default ExternalLink
