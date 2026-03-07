import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { Card, CardContent } from "@/components/ui/card";
import { Pagination, type PaginationMeta } from "@/components/ui/pagination";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
  TableEmpty,
} from "@/components/ui/data-table";
import { TableToolbar } from "@/components/table-toolbar";
import { useAuth } from "@/hooks/use-auth";
import {
  getTable,
  getDisplayableColumns,
  getDefaultColumnKeys,
  type TableDef,
  type FilterRule,
  type SortOption,
} from "@/lib/table-registry";
import { z } from "zod/v4";
import { useState, useDeferredValue, type ReactNode } from "react";

// ============================================================================
// Search schema — shared by all resource table routes
// ============================================================================

const filterSchema = z.object({
  id: z.string(),
  field: z.string(),
  operator: z.string(),
  value: z.string(),
});

export const resourceSearchSchema = z.object({
  page: z.coerce.number().optional().default(1),
  sort: z.string().optional(),
  dir: z.enum(["asc", "desc"]).optional(),
  search: z.string().optional(),
  filters: z.preprocess((val) => {
    if (typeof val === "string") {
      try {
        return JSON.parse(val);
      } catch {
        return [];
      }
    }
    return val ?? [];
  }, z.array(filterSchema).optional().default([])),
  columns: z.preprocess((val) => {
    if (typeof val === "string") return val.split(",");
    return val ?? undefined;
  }, z.array(z.string()).optional()),
});

export type ResourceSearch = z.infer<typeof resourceSearchSchema>;

// ============================================================================
// Props
// ============================================================================

interface ResourceTableProps<T> {
  /** Registry key (e.g., 'products') */
  tableKey: string;
  /** TanStack Query key prefix (e.g., 'products') */
  queryKey: string;
  /** Function that calls the SDK to fetch data */
  queryFn: (
    params: Record<string, unknown>,
  ) => Promise<{ data: T[]; meta: PaginationMeta }>;
  /** Current search params from the route */
  searchParams: ResourceSearch;
  /** Title displayed in the toolbar header. Overrides the table definition's title. */
  title?: string;
  /** Actions to render in the toolbar (e.g., "Add Product" button) */
  actions?: ReactNode;
}

// ============================================================================
// Component
// ============================================================================

export function ResourceTable<T extends Record<string, any>>({
  tableKey,
  queryKey,
  queryFn,
  searchParams,
  title,
  actions,
}: ResourceTableProps<T>) {
  const table = getTable<T>(tableKey);
  const { token } = useAuth();
  const navigate = useNavigate();

  const {
    page,
    sort: urlSort,
    dir: urlDir,
    search,
    filters,
    columns: urlColumns,
  } = searchParams;

  const defaultSort = table.defaultSort ?? {
    field: "updated_at",
    direction: "desc" as const,
  };
  const sort = urlSort ?? defaultSort.field;
  const dir = urlDir ?? defaultSort.direction;

  const [searchInput, setSearchInput] = useState(search ?? "");
  const deferredSearch = useDeferredValue(searchInput);

  const displayableColumns = getDisplayableColumns(table);
  const defaultColumnKeys = getDefaultColumnKeys(table);
  const visibleColumnKeys = urlColumns ?? defaultColumnKeys;

  const visibleColumns = displayableColumns.filter((c) =>
    visibleColumnKeys.includes(c.key),
  );

  // Build API params
  const sortString = dir === "desc" ? `-${sort}` : sort;

  const { data, isLoading } = useQuery({
    queryKey: [
      queryKey,
      { page, sort: sortString, search: deferredSearch, filters },
    ],
    queryFn: () => {
      const params: Record<string, unknown> = { page, sort: sortString };

      if (deferredSearch) {
        const searchParam = table.searchParam ?? "name_cont";
        params[searchParam] = deferredSearch;
      }

      // Convert FilterRule[] to Ransack params
      for (const filter of filters as FilterRule[]) {
        const col = table.columns.find((c) => c.key === filter.field);
        const ransackKey = col?.ransackAttribute ?? filter.field;
        params[`${ransackKey}_${filter.operator}`] = filter.value;
      }

      return queryFn(params);
    },
    enabled: !!token,
  });

  const rows = data?.data ?? [];
  const meta = data?.meta;

  // Navigation helpers
  function updateSearch(updates: Record<string, unknown>) {
    navigate({
      search: (prev: Record<string, unknown>) => ({ ...prev, ...updates }),
    });
  }

  function handleSearchChange(value: string) {
    setSearchInput(value);
    updateSearch({ search: value || undefined, page: 1 });
  }

  function handleSortChange(s: SortOption) {
    updateSearch({ sort: s.field, dir: s.direction, page: 1 });
  }

  function handleFiltersChange(f: FilterRule[]) {
    updateSearch({
      filters: f.length > 0 ? JSON.stringify(f) : undefined,
      page: 1,
    });
  }

  function handleColumnsChange(cols: string[]) {
    const isDefault =
      cols.length === defaultColumnKeys.length &&
      cols.every((c) => defaultColumnKeys.includes(c));
    updateSearch({ columns: isDefault ? undefined : cols.join(",") });
  }

  // Header columns for price-like right-aligned columns
  const headerColumns = visibleColumns.map((col) => {
    const isRightAligned = col.className?.includes("text-right");
    return {
      ...col,
      headerClassName: isRightAligned ? "text-right" : undefined,
    };
  });

  return (
    <Card className="rounded-2xl">
      <TableToolbar
        columns={displayableColumns}
        visibleColumns={visibleColumnKeys}
        onVisibleColumnsChange={handleColumnsChange}
        search={searchInput}
        onSearchChange={handleSearchChange}
        searchPlaceholder={table.searchPlaceholder ?? "Search..."}
        sort={{ field: sort, direction: dir }}
        onSortChange={handleSortChange}
        filters={filters as FilterRule[]}
        onFiltersChange={handleFiltersChange}
        allColumns={table.columns}
        title={title ?? table.title}
        actions={actions}
      />
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <tr>
              {headerColumns.map((col) => (
                <TableHead key={col.key} className={col.headerClassName}>
                  {col.label}
                </TableHead>
              ))}
            </tr>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableEmpty colSpan={visibleColumns.length}>
                Loading...
              </TableEmpty>
            ) : rows.length === 0 ? (
              <TableEmpty colSpan={visibleColumns.length}>
                <div className="flex flex-col items-center gap-2">
                  {table.emptyIcon}
                  <p>{table.emptyMessage ?? "No results found"}</p>
                  {(deferredSearch || (filters as FilterRule[]).length > 0) && (
                    <p className="text-xs">
                      Try adjusting your search or filters
                    </p>
                  )}
                </div>
              </TableEmpty>
            ) : (
              rows.map((row, i) => (
                <TableRow key={(row as any).id ?? i}>
                  {visibleColumns.map((col) => (
                    <TableCell key={col.key} className={col.className}>
                      {col.render
                        ? col.render(row)
                        : String((row as any)[col.key] ?? "—")}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
        {meta && (
          <Pagination
            meta={meta}
            onPageChange={(p) => updateSearch({ page: p })}
          />
        )}
      </CardContent>
    </Card>
  );
}
