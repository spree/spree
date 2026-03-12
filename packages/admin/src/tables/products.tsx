import { Link } from "@tanstack/react-router";
import { PackageIcon } from "lucide-react";
import { StatusBadge } from "@/components/ui/badge";
import { formatPrice, formatRelativeTime } from "@/lib/formatters";
import { defineTable } from "@/lib/table-registry";

defineTable("products", {
  title: "Products",
  searchParam: "multi_search",
  searchPlaceholder: "Search products...",
  defaultSort: { field: "updated_at", direction: "desc" },
  emptyIcon: <PackageIcon className="size-8 text-muted-foreground/50" />,
  emptyMessage: "No products found",
  columns: [
    {
      key: "name",
      label: "Name",
      sortable: true,
      filterable: true,
      default: true,
      render: (product) => (
        <Link
          to="/products/$productId"
          params={{ productId: product.id }}
          className="flex items-center gap-3 no-underline"
        >
          <div className="flex size-10 shrink-0 items-center justify-center rounded-lg border border-gray-200 bg-gray-50 overflow-hidden">
            {product.thumbnail_url ? (
              <img
                src={product.thumbnail_url}
                alt={product.name}
                className="size-full object-cover"
              />
            ) : (
              <PackageIcon className="size-4 text-gray-400" />
            )}
          </div>
          <div className="min-w-0">
            <div className="truncate font-medium text-zinc-950">
              {product.name}
            </div>
          </div>
        </Link>
      ),
    },
    {
      key: "status",
      label: "Status",
      sortable: true,
      filterable: true,
      default: true,
      filterType: "status",
      filterOptions: [
        { value: "draft", label: "Draft" },
        { value: "active", label: "Active" },
        { value: "archived", label: "Archived" },
      ],
      render: (product) => <StatusBadge status={product.status} />,
    },
    {
      key: "inventory",
      label: "Inventory",
      sortable: false,
      filterable: false,
      default: true,
      render: (product) => {
        const variantCount = product.variant_count;

        const inventoryStatus =
          !product.in_stock && !product.backorderable ? (
            <span className="text-sm text-destructive">Out of stock</span>
          ) : product.backorderable && !product.in_stock ? (
            <span className="text-sm text-muted-foreground">On backorder</span>
          ) : (
            <span className="text-sm text-muted-foreground">
              {product.total_on_hand} in stock
            </span>
          );

        return (
          <span>
            {inventoryStatus}
            {variantCount > 1 ? (
              <>
                &nbsp; &#8211; &nbsp;
                <span className="text-sm text-muted-foreground">
                  {variantCount} variants
                </span>
              </>
            ) : (
              ""
            )}
          </span>
        );
      },
    },
    {
      key: "sku",
      label: "SKU",
      sortable: false,
      filterable: true,
      default: false,
      ransackAttribute: "master_sku",
      className: "text-sm text-muted-foreground",
      render: (product) => product.sku ?? "—",
    },
    {
      key: "price",
      label: "Price",
      sortable: true,
      filterable: true,
      default: true,
      filterType: "number",
      ransackAttribute: "master_price",
      className: "text-right tabular-nums whitespace-nowrap",
      render: (product) => (product.price ? formatPrice(product.price) : "—"),
    },
    {
      key: "created_at",
      label: "Created at",
      sortable: true,
      filterable: true,
      default: false,
      filterType: "date",
      className: "text-sm text-muted-foreground whitespace-nowrap",
      render: (product) => formatRelativeTime(product.created_at),
    },
    {
      key: "updated_at",
      label: "Updated at",
      sortable: true,
      filterable: true,
      default: false,
      filterType: "date",
      className: "text-sm text-muted-foreground whitespace-nowrap",
      render: (product) => formatRelativeTime(product.updated_at),
    },
    {
      key: "in_stock",
      label: "In Stock",
      filterable: true,
      filterType: "boolean",
      displayable: false,
      default: false,
    },
  ],
});
