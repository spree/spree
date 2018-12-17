import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

import IconClose from 'react-feather/dist/icons/chevron-right'
import IconOpen from 'react-feather/dist/icons/chevron-down'

const SidebarRootLink = ({
  isOpen,
  toggleSection,
  itemsLength,
  title,
  href
}) => (
  <h3 className="flex items-center mt0 fw5 f5 f4-l">
    {isOpen ? (
      <IconOpen className="pointer moon-gray" onClick={() => toggleSection()} />
    ) : (
      <IconClose
        className="pointer moon-gray"
        onClick={() => toggleSection()}
      />
    )}

    {itemsLength > 0 ? (
      <Link
        to={href}
        activeClassName="spree-green"
        className="link spree-blue db fw5 ml3"
      >
        {title}
      </Link>
    ) : (
      <span className="pointer spree-blue ml3" onClick={() => toggleSection()}>
        {title}
      </span>
    )}
  </h3>
)

SidebarRootLink.propTypes = {
  isOpen: PropTypes.bool.isRequired,
  toggleSection: PropTypes.func.isRequired,
  itemsLength: PropTypes.number.isRequired,
  title: PropTypes.string.isRequired,
  href: PropTypes.oneOfType([PropTypes.string, PropTypes.bool]).isRequired
}

export default SidebarRootLink
