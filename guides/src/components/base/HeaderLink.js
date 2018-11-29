import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import IconLink from 'react-feather/dist/icons/link-2'

const HeaderLink = ({ text, children }) => (
  <a href={`#${kebabCase(text)}`} className="db link flex">
    <IconLink className="child absolute pr1 top-0 mt2 left--2" />
    <span className="blue db">{children}</span>
  </a>
)

HeaderLink.propTypes = {
  text: PropTypes.node.isRequired,
  children: PropTypes.node
}

export default HeaderLink
