import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import IconLink from 'react-feather/dist/icons/link-2'

const HeaderLink = ({ text }) => (
  <a href={`#${kebabCase(text)}`} className="left--2 db link absolute child">
    <IconLink className="pt2" />
  </a>
)

HeaderLink.propTypes = {
  text: PropTypes.node.isRequired
}

export default HeaderLink
