import { cva, type VariantProps } from 'class-variance-authority'

import { cn } from '@/lib/utils'

const badgeVariants = cva(
  'inline-flex items-center whitespace-nowrap text-xs font-normal leading-none rounded-md py-1 px-2',
  {
    variants: {
      variant: {
        default: 'bg-white text-gray-600 border border-gray-200',
        active: 'bg-green-200 text-green-900 border border-transparent',
        warning: 'bg-yellow-200 text-yellow-900 border border-transparent',
        danger: 'bg-red-100 text-red-900 border border-transparent',
        info: 'bg-blue-50 text-blue-900 border border-transparent',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
)

function Badge({
  className,
  variant,
  ...props
}: React.ComponentProps<'span'> & VariantProps<typeof badgeVariants>) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />
}

const statusVariantMap: Record<string, VariantProps<typeof badgeVariants>['variant']> = {
  active: 'active',
  complete: 'active',
  completed: 'active',
  paid: 'active',
  shipped: 'active',
  published: 'active',
  approved: 'active',
  ready: 'active',
  draft: 'default',
  pending: 'default',
  processing: 'default',
  inactive: 'default',
  cart: 'default',
  address: 'default',
  delivery: 'default',
  payment: 'default',
  confirm: 'default',
  resumed: 'info',
  partial: 'warning',
  archived: 'warning',
  returned: 'warning',
  backorder: 'warning',
  balance_due: 'warning',
  credit_owed: 'warning',
  canceled: 'danger',
  failed: 'danger',
  void: 'danger',
  error: 'danger',
  rejected: 'danger',
}

function StatusBadge({ status, className }: { status: string; className?: string }) {
  const variant = statusVariantMap[status] ?? 'default'
  return (
    <Badge variant={variant} className={cn('capitalize', className)}>
      {status.replace(/_/g, ' ')}
    </Badge>
  )
}

export { Badge, StatusBadge, badgeVariants }
