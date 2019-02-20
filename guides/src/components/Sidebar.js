// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import { equals, or, length, filter } from 'ramda'
import startCase from 'lodash.startcase'
import { cx } from 'emotion'

// --- Utils
import style from '../utils/styles'
import capitalize from '../utils/capitalize'

// --- Components
import SidebarRootLink from './SidebarRootLink'

/**
 * Helpers
 */

const byOnlyNonIndexNodes = item => !item.node.fields.isIndex
const byOnlyIndexNodes = item => item.node.fields.isIndex

const navBlockIndex = block => filter(byOnlyIndexNodes, block)
const normalizeNavBlock = block => filter(byOnlyNonIndexNodes, block)

const getNavBlockIndexSlug = block =>
  navBlockIndex(block)[0]['node']['fields']['slug']

const getFirstNavItemSlug = block =>
  block.length > 0 ? block[0]['node']['fields']['slug'] : false

/**
 * Component
 */

export default class Sidebar extends React.PureComponent {
  static propTypes = {
    nav: PropTypes.array.isRequired,
    activeSection: PropTypes.string,
    isMobile: PropTypes.bool
  }

  state = {
    openSection: null
  }

  sectionIsOpen = section =>
    or(
      equals(section, this.state.openSection),
      equals(section, this.props.activeSection)
    )

  _toggleSection = section => {
    this.setState(prevState => {
      return { openSection: prevState.openSection !== section ? section : null }
    })
  }

  render() {
    return (
      <>
        {this.props.nav && (
          <aside
            className={cx(
              {
                'dn db-l fixed-l br bg-near-white b--light-gray ph4 pt4 vh-100': !this
                  .props.isMobile
              },
              { 'db pt2 bg-white': this.props.isMobile },
              'overflow-auto z-2'
            )}
            css={{
              width: style.sidebar.width
            }}
          >
            <nav>
              <ul className="list ma0 pl0">
                {this.props.nav.map((item, index) => (
                  <React.Fragment key={index}>
                    {length(normalizeNavBlock(item.edges)) > 0 && (
                      <li key={index}>
                        <SidebarRootLink
                          isSingleRoot={length(this.props.nav) < 2}
                          title={capitalize(startCase(item.section))}
                          isOpen={this.sectionIsOpen(item.section)}
                          toggleSection={() =>
                            this._toggleSection(item.section)
                          }
                          itemsLength={length(item.edges)}
                          href={
                            length(navBlockIndex(item.edges)) > 0
                              ? getNavBlockIndexSlug(item.edges)
                              : getFirstNavItemSlug(item.edges)
                          }
                        />
                        <ul
                          className={cx(
                            { db: this.sectionIsOpen(item.section) },
                            {
                              dn:
                                !this.sectionIsOpen(item.section) &&
                                length(this.props.nav) > 2
                            },
                            {
                              'db dn-l':
                                !this.sectionIsOpen(item.section) &&
                                length(this.props.nav) < 2
                            },
                            'list pl2 ml4 mb4'
                          )}
                        >
                          {normalizeNavBlock(item.edges).map((item, index) => (
                            <li key={index}>
                              <Link
                                to={item.node.fields.slug}
                                activeClassName="spree-green fw6"
                                className="link gray db mv2 fw4"
                              >
                                {item.node.frontmatter.title}
                              </Link>
                            </li>
                          ))}
                        </ul>
                      </li>
                    )}
                  </React.Fragment>
                ))}
              </ul>
            </nav>
          </aside>
        )}
      </>
    )
  }
}
