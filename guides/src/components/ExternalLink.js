import * as React from 'react'
import PropTypes from 'prop-types'

const ExternalLink = ({ url, children }) => (
  <a href={url} rel="nofollow" target="_blank">
    {children}
  </a>
)

ExternalLink.propTypes = {
  url: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired
}

export default ExternalLink
