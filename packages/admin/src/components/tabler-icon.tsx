import {
  BarChart3Icon,
  BookOpenIcon,
  HomeIcon,
  InboxIcon,
  LogOutIcon,
  type LucideIcon,
  MailIcon,
  MessageCircleIcon,
  PackageIcon,
  PaletteIcon,
  PlugIcon,
  ReceiptIcon,
  SettingsIcon,
  StoreIcon,
  TagIcon,
  UserIcon,
  UsersIcon,
} from 'lucide-react'
import { cn } from '@/lib/utils'

const iconMap: Record<string, LucideIcon> = {
  home: HomeIcon,
  inbox: InboxIcon,
  package: PackageIcon,
  users: UsersIcon,
  discount: TagIcon,
  'chart-bar': BarChart3Icon,
  settings: SettingsIcon,
  'receipt-refund': ReceiptIcon,
  'plug-connected': PlugIcon,
  'building-store': StoreIcon,
  palette: PaletteIcon,
  'user-scan': UserIcon,
  'log-out': LogOutIcon,
  book: BookOpenIcon,
  'message-circle': MessageCircleIcon,
  mail: MailIcon,
}

interface TablerIconProps {
  name: string
  className?: string
}

export function TablerIcon({ name, className }: TablerIconProps) {
  const Icon = iconMap[name] ?? StoreIcon

  return <Icon className={cn('size-4', className)} />
}
