// index.js

// Feature highlights for the project
const features = [
  {
    title: 'Revamped Admin Dashboard',
    description: "A completely redesigned Admin Dashboard experience to boost your team's productivity.",
    icon: '📊'
  },
  {
    title: 'Mobile-First, No-Code Storefront',
    description: 'A mobile-first, no-code customizable storefront designed to increase conversions and customer loyalty.',
    icon: '📱'
  },
  {
    title: 'Powerful Integrations',
    description: 'New native Stripe and Stripe Connect integrations, plus Klaviyo available with the Enterprise Edition.',
    icon: '🔌'
  }
]

// Simple function to render features (could be used with React, Vue, or plain JS)
function renderFeatures(features) {
  features.forEach(feature => {
    console.log(`${feature.icon}  ${feature.title}\n  ${feature.description}\n`)
  })
}

// Execute rendering (for now just console output)
renderFeatures(features)
