const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    'public/*.html',
    'app/helpers/**/*.rb',
    'app/javascript/**/*.js',
    'app/views/spree/**/*.erb',
    'app/views/devise/**/*.erb',
    'app/views/themes/**/*.erb',
    process.env.SPREE_STOREFRONT_PATH + '/app/helpers/**/*.rb',
    process.env.SPREE_STOREFRONT_PATH + '/app/javascript/**/*.js',
    process.env.SPREE_STOREFRONT_PATH + '/app/views/themes/**/*.erb',
    process.env.SPREE_STOREFRONT_PATH + '/app/views/spree/**/*.erb',
    process.env.SPREE_STOREFRONT_PATH + '/app/views/devise/**/*.erb'
  ],
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio')
  ],
  variants: {
    scrollbar: ['rounded']
  },
  safelist: [
    'hidden',
    'lg:grid',
    'grid',
    'text-xs',
    'text-sm',
    'text-base',
    'text-lg',
    'text-xl',
    'text-2xl',
    'text-3xl',
    'text-4xl',
    'text-left',
    'text-right',
    'text-center',
    'cursor-wait',
    'lg:sr-only'
  ],
  theme: {
    extend: {
      fontFamily: {
        body: ['var(--font-body)', ...defaultTheme.fontFamily.sans]
      },
      screens: {
        lg: { raw: '(min-width: 1024px) { &:not(.force-mobile-view *) }' }
      },
      animation: {
        fadeIn: 'fadeIn 0.5s ease-in-out'
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: 0 },
          '100%': { opacity: 1 }
        }
      },
      colors: {
        primary: 'var(--primary)',
        accent: 'var(--accent)',
        neutral: 'var(--neutral)',
        danger: 'var(--danger)',
        success: 'var(--success)',

        'accent-100': 'var(--accent-100)',
        'neutral-50': 'var(--neutral-50)',
        'neutral-100': 'var(--neutral-100)',
        'neutral-200': 'var(--neutral-200)',
        'neutral-300': 'var(--neutral-300)',
        'neutral-400': 'var(--neutral-400)',
        'neutral-500': 'var(--neutral-500)',
        'neutral-600': 'var(--neutral-600)',
        'neutral-700': 'var(--neutral-700)',
        'neutral-800': 'var(--neutral-800)',
        'neutral-900': 'var(--neutral-900)',

        background: 'var(--background)',
        'section-background': 'var(--section-background, var(--background))',
        text: 'var(--text)',

        button: 'rgba(var(--button-rgb), <alpha-value>)',
        'button-text': 'var(--button-text)',
        'button-hover': 'var(--button-hover)',
        'button-hover-text': 'var(--button-hover-text)',

        'secondary-button': 'var(--secondary-button)',
        'secondary-button-text': 'var(--secondary-button-text)',
        'secondary-button-hover': 'var(--secondary-button-hover)',
        'secondary-button-hover-text': 'var(--secondary-button-hover-text)',

        'button-light': 'var(--button-light)',
        'button-light-text': 'var(--button-light-text)',
        'button-light-hover': 'var(--button-light-hover)',
        'button-light-hover-text': 'var(--button-light-hover-text)',

        input: 'var(--input)',
        'input-bg': 'var(--input-bg)',
        'input-text': 'var(--input-text)',
        'input-focus': 'var(--input-focus)',
        'input-focus-bg': 'var(--input-focus-bg)',
        'input-focus-text': 'var(--input-focus-text)'
      },
      letterSpacing: {
        widest: '0.07rem'
      },
      typography: {
        DEFAULT: {
          css: {
            '--tw-prose-body': 'var(--text)',
            '--tw-prose-headings': 'var(--text)',
            '--tw-prose-bold': 'var(--text)',
            '--tw-prose-links': 'var(--text)',
            '--tw-prose-counters': 'var(--text)',
            '--tw-prose-bullets': 'var(--text)',
            '--tw-prose-lead': 'var(--text)',
            '--tw-prose-hr': 'var(--border-default-color)',
            '--tw-prose-th-borders': 'var(--border-default-color)',
            '--tw-prose-td-borders': 'var(--border-default-color)',
            '--tw-prose-quote-borders': 'var(--border-default-color)',
            '--tw-prose-quotes': 'var(--text)'
          }
        }
      }
    }
  }
}
