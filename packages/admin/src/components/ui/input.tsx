import * as React from "react"

import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "block w-full min-w-0 rounded-lg border border-border bg-white py-2 px-3 text-sm font-normal leading-normal text-foreground shadow-xs transition-all duration-100 ease-in-out outline-none placeholder:text-muted-foreground focus:outline-2 focus:outline-offset-2 focus:outline-blue-500 focus:border-border focus:ring-0 disabled:pointer-events-none disabled:cursor-not-allowed disabled:bg-gray-50 disabled:border-gray-100 disabled:text-muted-foreground disabled:shadow-none file:inline-flex file:h-6 file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground aria-invalid:border-destructive",
        className
      )}
      {...props}
    />
  )
}

export { Input }
