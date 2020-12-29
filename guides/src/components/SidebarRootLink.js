// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import { cx } from 'emotion'

// --- Icons
import IconClose from 'react-feather/dist/icons/chevron-right'
import IconOpen from 'react-feather/dist/icons/chevron-down'

/**
 * Component
 */

const SidebarRootLink = ({
  isSingleRoot,
  isOpen,
  toggleSection,
  itemsLength,
  title,
  href
}) => (
  <h3
    className={cx(
      { 'flex items-center': !isSingleRoot },
      { 'dn flex-l items-center-l': isSingleRoot },
      'mt0 fw5 f5 f4-l'
    )}
  >
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
        className={cx({ 'spree-green': isOpen }, 'link spree-blue db fw5 ml3')}
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
  isSingleRoot: PropTypes.bool.isRequired,
  isOpen: PropTypes.bool.isRequired,
  toggleSection: PropTypes.func.isRequired,
  itemsLength: PropTypes.number.isRequired,
  title: PropTypes.string.isRequired,
  href: PropTypes.oneOfType([PropTypes.string, PropTypes.bool]).isRequired
}

export default SidebarRootLink
