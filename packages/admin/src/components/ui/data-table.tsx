import { cn } from "@/lib/utils"
import type { ReactNode } from "react"

function Table({ className, ...props }: React.ComponentProps<"table">) {
  return (
    <div className="overflow-x-auto">
      <table
        className={cn("w-full align-top text-foreground", className)}
        {...props}
      />
    </div>
  )
}

function TableHeader({ className, ...props }: React.ComponentProps<"thead">) {
  return <thead className={cn("align-bottom", className)} {...props} />
}

function TableBody({ className, ...props }: React.ComponentProps<"tbody">) {
  return <tbody className={cn("align-middle", className)} {...props} />
}

function TableRow({ className, ...props }: React.ComponentProps<"tr">) {
  return (
    <tr
      className={cn(
        "group/row hover:bg-gray-50/75 last:*:border-b-0",
        className
      )}
      {...props}
    />
  )
}

function TableHead({ className, ...props }: React.ComponentProps<"th">) {
  return (
    <th
      className={cn(
        "text-left text-sm font-medium text-gray-600 bg-muted py-2 px-3 border-b border-gray-200 whitespace-nowrap first:pl-4 last:pr-4 first:rounded-tl-2xl last:rounded-tr-2xl",
        className
      )}
      {...props}
    />
  )
}

function TableCell({ className, ...props }: React.ComponentProps<"td">) {
  return (
    <td
      className={cn(
        "py-4 px-3 border-b border-gray-200 align-middle first:pl-4 last:pr-4 group-last/row:first:rounded-bl-xl group-last/row:last:rounded-br-xl",
        className
      )}
      {...props}
    />
  )
}

function TableEmpty({ children, colSpan }: { children: ReactNode; colSpan: number }) {
  return (
    <tr>
      <td colSpan={colSpan} className="py-12 text-center text-muted-foreground">
        {children}
      </td>
    </tr>
  )
}

export { Table, TableHeader, TableBody, TableRow, TableHead, TableCell, TableEmpty }
