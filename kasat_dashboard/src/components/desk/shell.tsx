"use client";

import * as Dialog from "@radix-ui/react-dialog";
import {
  Bell,
  ChevronRight,
  CircleHelp,
  LayoutGrid,
  LogOut,
  Monitor,
  Moon,
  PanelLeft,
  Plus,
  Search,
  Settings,
  Sun,
  UserRound,
} from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import { Button } from "@/components/ui/button";
import { DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import {
  categoryLabel,
  OPERATOR,
  priorityLabel,
  queueCounts,
  spaceTypeLabel,
  type QueueId,
} from "@/lib/desk";
import { isSupabaseConfigured } from "@/lib/supabase";
import { CATEGORIES, PRIORITIES, type CategoryCode, type Priority } from "@/lib/types";
import { cn } from "@/lib/utils";

import { SpaceGlyph } from "./bits";
import { useDesk } from "./desk-store";

const QUEUE_LINKS: { id: QueueId; href: string; label: "queueUnclaimed" | "queueMine" | "queueOpen" | "queueWaiting" | "queueResolved" }[] = [
  { id: "unclaimed", href: "/queues/unclaimed", label: "queueUnclaimed" },
  { id: "mine", href: "/queues/mine", label: "queueMine" },
  { id: "open", href: "/queues/open", label: "queueOpen" },
  { id: "waiting", href: "/queues/waiting", label: "queueWaiting" },
  { id: "resolved", href: "/queues/resolved", label: "queueResolved" },
];

const SETTINGS = [
  { href: "/settings/details", label: "details" },
  { href: "/settings/people", label: "people" },
  { href: "/settings/permissions", label: "permissions" },
  { href: "/settings/workflow", label: "workflow" },
  { href: "/settings/notifications", label: "notifications" },
  { href: "/settings/language", label: "language" },
] as const;

function useMedia(query: string) {
  const [matches, setMatches] = useState(false);
  useEffect(() => {
    const media = window.matchMedia(query);
    const apply = () => setMatches(media.matches);
    apply();
    media.addEventListener("change", apply);
    return () => media.removeEventListener("change", apply);
  }, [query]);
  return matches;
}

function ThemeThumb({ mode }: { mode: "light" | "dark" | "system" }) {
  if (mode === "system") {
    return (
      <span className="flex h-8 w-12 overflow-hidden rounded-[4px] border border-border" aria-hidden="true">
        <span className="h-full w-1/2 bg-white" />
        <span className="h-full w-1/2 bg-[#1D2125]" />
      </span>
    );
  }
  const dark = mode === "dark";
  return (
    <span
      className={cn("flex h-8 w-12 items-end rounded-[4px] border border-border p-1", dark ? "bg-[#1D2125]" : "bg-white")}
      aria-hidden="true"
    >
      <span className={cn("mb-1 h-1 w-7 rounded-full", dark ? "bg-[#579DFF]" : "bg-[#0C66E4]")} />
    </span>
  );
}

function DisabledTip({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span className="inline-flex" tabIndex={0}>
          {children}
        </span>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}

export function Shell({ children }: { children: React.ReactNode }) {
  const { t } = useI18n();
  const pathname = usePathname();
  const router = useRouter();
  const { incidents, space, createCase } = useDesk();
  const narrow = useMedia("(max-width: 1023px)");
  const [collapsed, setCollapsed] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [createOpen, setCreateOpen] = useState(false);
  const [helpOpen, setHelpOpen] = useState(false);
  const counts = queueCounts(incidents);

  useEffect(() => {
    setDrawerOpen(false);
  }, [pathname]);

  useEffect(() => {
    const saved = window.localStorage.getItem("kasat.desk.sidebar");
    if (saved === "icons") setCollapsed(true);
  }, []);

  function toggleSidebar() {
    if (narrow) {
      setDrawerOpen((open) => !open);
      return;
    }
    setCollapsed((value) => {
      const next = !value;
      window.localStorage.setItem("kasat.desk.sidebar", next ? "icons" : "full");
      return next;
    });
  }

  function onSearch(event: React.FormEvent) {
    event.preventDefault();
    const term = query.trim();
    if (!term) return;
    const match = incidents.find(
      (item) => item.trackingId.toLowerCase() === term.toLowerCase() || item.description.toLowerCase().includes(term.toLowerCase()),
    );
    if (match) router.push(`/cases/${match.trackingId}`);
    else router.push(`/queues/open?q=${encodeURIComponent(term)}`);
  }

  async function logOut() {
    if (isSupabaseConfigured()) {
      const { getSupabaseBrowserClient } = await import("@/lib/supabase");
      await getSupabaseBrowserClient().auth.signOut();
    }
    router.push("/login");
  }

  const iconOnly = collapsed && !narrow;
  const sidebar = (
    <div className="flex h-full flex-col gap-4 overflow-y-auto p-3">
      <DropdownMenu>
        <DropdownMenuTrigger
          className={cn(
            "flex w-full items-center gap-2 rounded-[6px] border border-border px-2 py-2 text-left hover:bg-surface",
            iconOnly && "justify-center px-0",
          )}
          aria-label={space.name}
        >
          <span className="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-[6px] bg-surface">
            <SpaceGlyph icon={space.icon} />
          </span>
          {iconOnly ? null : (
            <span className="min-w-0">
              <span className="block truncate text-sm font-medium">{space.name}</span>
              <span className="block truncate text-xs text-muted">
                {space.type === "police" ? t("policeSpace") : spaceTypeLabel(space.type, t)}
              </span>
            </span>
          )}
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start">
          <DropdownMenuLabel>{t("orgName")}</DropdownMenuLabel>
          <DropdownMenuItem>
            <SpaceGlyph icon={space.icon} />
            <span className="min-w-0 flex-1 truncate">{space.name}</span>
            <span className="text-xs text-muted">{t("current")}</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <nav aria-label={t("queues")} className="grid gap-3">
        <NavGroup title={t("queues")} hidden={iconOnly}>
          {QUEUE_LINKS.map((link) => (
            <NavItem
              key={link.id}
              href={link.href}
              label={t(link.label)}
              count={counts[link.id]}
              active={pathname === link.href}
              iconOnly={iconOnly}
            />
          ))}
        </NavGroup>
        <NavGroup title={t("views")} hidden={iconOnly}>
          <NavItem href="/reports" label={t("reports")} active={pathname === "/reports"} iconOnly={iconOnly} />
          <NavItem href="/access-log" label={t("accessLog")} active={pathname === "/access-log"} iconOnly={iconOnly} />
        </NavGroup>
        <NavGroup title={t("spaceSettings")} hidden={iconOnly}>
          {SETTINGS.map((item) => (
            <NavItem
              key={item.href}
              href={item.href}
              label={t(item.label)}
              active={pathname === item.href}
              iconOnly={iconOnly}
            />
          ))}
        </NavGroup>
      </nav>
    </div>
  );

  return (
    <div className="min-h-screen bg-surface text-text">
      <header className="sticky top-0 z-30 flex h-12 items-center gap-2 border-b border-border bg-bg px-3">
        <Button variant="ghost" size="icon" aria-label={t("toggleSidebar")} onClick={toggleSidebar}>
          <PanelLeft className="h-4 w-4" aria-hidden="true" />
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger className="inline-flex h-8 w-8 items-center justify-center rounded-[6px] hover:bg-surface" aria-label={t("openAppSwitcher")}>
            <LayoutGrid className="h-4 w-4" aria-hidden="true" />
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            <DropdownMenuLabel>{t("appSwitcherLabel")}</DropdownMenuLabel>
            <DropdownMenuItem>
              <img src="/brand/kasat-bloom.svg" alt="" width={16} height={16} />
              {t("appName")}
              <span className="ml-auto text-xs text-muted">{t("current")}</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <Link href="/queues/unclaimed" className="flex items-center gap-2 pr-2">
          <img src="/brand/kasat-bloom.svg" alt="" width={20} height={20} />
          <span className="hidden font-semibold sm:inline">{t("appName")}</span>
        </Link>
        <form onSubmit={onSearch} className="mx-auto hidden w-full max-w-[420px] md:block" role="search">
          <label className="relative block">
            <span className="sr-only">{t("searchLabel")}</span>
            <Search className="pointer-events-none absolute top-2 left-2 h-4 w-4 text-muted" aria-hidden="true" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t("searchPlaceholder")}
              className="h-8 w-full rounded-[6px] border border-border bg-bg pr-2 pl-8"
            />
          </label>
        </form>
        <div className="ml-auto flex items-center gap-1">
          <Button variant="primary" onClick={() => setCreateOpen(true)}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            {t("create")}
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger className="inline-flex h-8 w-8 items-center justify-center rounded-[6px] hover:bg-surface" aria-label={t("notificationsBell")}>
              <Bell className="h-4 w-4" aria-hidden="true" />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>{t("notifications")}</DropdownMenuLabel>
              <DropdownMenuItem disabled>{t("notificationsEmpty")}</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <Button variant="ghost" size="icon" aria-label={t("helpButton")} onClick={() => setHelpOpen(true)}>
            <CircleHelp className="h-4 w-4" aria-hidden="true" />
          </Button>
          <Button variant="ghost" size="icon" aria-label={t("settingsButton")} onClick={() => router.push("/settings/details")}>
            <Settings className="h-4 w-4" aria-hidden="true" />
          </Button>
          <AccountMenu onLogOut={logOut} />
        </div>
      </header>

      <div className="flex min-h-[calc(100vh-48px)]">
        {narrow ? (
          drawerOpen ? (
            <div className="fixed inset-0 z-40">
              <button className="absolute inset-0 bg-[#172B4D]/40" aria-label={t("close")} onClick={() => setDrawerOpen(false)} />
              <aside className="absolute inset-y-0 left-0 w-[240px] border-r border-border bg-bg">{sidebar}</aside>
            </div>
          ) : null
        ) : (
          <aside className={cn("sticky top-12 h-[calc(100vh-48px)] shrink-0 border-r border-border bg-bg", iconOnly ? "w-16" : "w-[240px]")}>
            {sidebar}
          </aside>
        )}
        <div className="min-w-0 flex-1">{children}</div>
      </div>

      <CreateCaseDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        onCreate={(input) => {
          const id = createCase(input);
          setCreateOpen(false);
          router.push(`/cases/${id}`);
        }}
      />
      <Dialog.Root open={helpOpen} onOpenChange={setHelpOpen}>
        <DialogContent closeLabel={t("close")}>
          <DialogTitle className="pr-8 text-base font-semibold">{t("help")}</DialogTitle>
          <DialogDescription className="mt-2 text-sm text-muted">{t("helpBody")}</DialogDescription>
        </DialogContent>
      </Dialog.Root>
    </div>
  );
}

function NavGroup({ title, hidden, children }: { title: string; hidden: boolean; children: React.ReactNode }) {
  return (
    <div className="grid gap-1">
      {hidden ? null : <p className="px-2 text-xs font-medium tracking-wide text-muted uppercase">{title}</p>}
      {children}
    </div>
  );
}

function NavItem({
  href,
  label,
  count,
  active,
  iconOnly,
}: {
  href: string;
  label: string;
  count?: number;
  active: boolean;
  iconOnly: boolean;
}) {
  const className = cn(
    "flex h-8 items-center gap-2 rounded-[6px] px-2 text-sm",
    active ? "bg-surface font-medium" : "hover:bg-surface",
    iconOnly && "justify-center px-0",
  );
  const body = (
    <>
      {iconOnly ? <span className="text-xs font-semibold">{label.slice(0, 1)}</span> : <span className="truncate">{label}</span>}
      {!iconOnly && count !== undefined ? <span className="ml-auto text-xs text-muted">{count}</span> : null}
    </>
  );
  if (!iconOnly) {
    return (
      <Link href={href} className={className} aria-current={active ? "page" : undefined}>
        {body}
      </Link>
    );
  }
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Link href={href} className={className} aria-label={label} aria-current={active ? "page" : undefined}>
          {body}
        </Link>
      </TooltipTrigger>
      <TooltipContent side="right">{label}</TooltipContent>
    </Tooltip>
  );
}

function AccountMenu({ onLogOut }: { onLogOut: () => void }) {
  const { t } = useI18n();
  const { theme, setTheme } = useTheme();
  const router = useRouter();
  const current = theme ?? "system";
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-primary text-xs font-semibold text-white"
        aria-label={t("accountMenu")}
      >
        {OPERATOR.initials}
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-[280px]">
        <div className="flex items-center gap-2 px-2 py-2">
          <span className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-primary text-sm font-semibold text-white">
            {OPERATOR.initials}
          </span>
          <span className="min-w-0">
            <span className="block truncate font-medium">{OPERATOR.name}</span>
            <span className="block truncate text-xs text-muted">{OPERATOR.email}</span>
            <span className="block truncate text-xs text-muted">{t("orgName")}</span>
          </span>
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={() => router.push("/account/profile")}>
          <UserRound className="h-4 w-4" aria-hidden="true" />
          {t("profile")}
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={() => router.push("/account/settings")}>
          <Settings className="h-4 w-4" aria-hidden="true" />
          {t("accountSettings")}
        </DropdownMenuItem>
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>
            <span className="flex items-center gap-2">
              <Sun className="h-4 w-4" aria-hidden="true" />
              {t("theme")}
            </span>
            <ChevronRight className="h-4 w-4" aria-hidden="true" />
          </DropdownMenuSubTrigger>
          <DropdownMenuSubContent>
            <DropdownMenuRadioGroup value={current} onValueChange={setTheme}>
              <ThemeChoice value="light" label={t("themeLight")} icon={<Sun className="h-4 w-4" aria-hidden="true" />} />
              <ThemeChoice value="dark" label={t("themeDark")} icon={<Moon className="h-4 w-4" aria-hidden="true" />} />
              <ThemeChoice value="system" label={t("themeSystem")} icon={<Monitor className="h-4 w-4" aria-hidden="true" />} />
            </DropdownMenuRadioGroup>
          </DropdownMenuSubContent>
        </DropdownMenuSub>
        <DropdownMenuSeparator />
        <DisabledTip label={t("oneAccount")}>
          <DropdownMenuItem disabled>
            {t("switchAccount")}
          </DropdownMenuItem>
        </DisabledTip>
        <DropdownMenuItem onSelect={onLogOut}>
          <LogOut className="h-4 w-4" aria-hidden="true" />
          {t("logOut")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function ThemeChoice({ value, label, icon }: { value: string; label: string; icon: React.ReactNode }) {
  return (
    <DropdownMenuRadioItem value={value} className="items-center">
      <ThemeThumb mode={value as "light" | "dark" | "system"} />
      <span className="flex items-center gap-2">
        {icon}
        {label}
      </span>
    </DropdownMenuRadioItem>
  );
}

function CreateCaseDialog({
  open,
  onOpenChange,
  onCreate,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreate: (input: { description: string; category: CategoryCode; priority: Priority; areaNote: string }) => void;
}) {
  const { t } = useI18n();
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<CategoryCode>("HRSMT");
  const [priority, setPriority] = useState<Priority>("P3");
  const [areaNote, setAreaNote] = useState("");

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <DialogContent closeLabel={t("close")}>
        <DialogTitle className="pr-8 text-base font-semibold">{t("createCase")}</DialogTitle>
        <DialogDescription className="mt-1 text-sm text-muted">{t("manualIntakeHelp")}</DialogDescription>
        <form
          className="mt-4 grid gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            if (!description.trim()) return;
            onCreate({ description, category, priority, areaNote });
            setDescription("");
            setAreaNote("");
          }}
        >
          <label className="grid gap-1 text-sm">
            {t("fieldSummary")}
            <textarea
              required
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              className="min-h-24 rounded-[6px] border border-border bg-bg p-2"
            />
          </label>
          <label className="grid gap-1 text-sm">
            {t("category")}
            <select
              value={category}
              onChange={(event) => setCategory(event.target.value as CategoryCode)}
              className="h-8 rounded-[6px] border border-border bg-bg px-2"
            >
              {CATEGORIES.map((item) => (
                <option key={item} value={item}>
                  {categoryLabel(item, t)}
                </option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-sm">
            {t("priority")}
            <select
              value={priority}
              onChange={(event) => setPriority(event.target.value as Priority)}
              className="h-8 rounded-[6px] border border-border bg-bg px-2"
            >
              {PRIORITIES.map((item) => (
                <option key={item} value={item}>
                  {priorityLabel(item, t)}
                </option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-sm">
            {t("generalArea")}
            <input
              value={areaNote}
              onChange={(event) => setAreaNote(event.target.value)}
              placeholder={t("generalAreaPlaceholder")}
              className="h-8 rounded-[6px] border border-border bg-bg px-2"
            />
          </label>
          <div className="flex justify-end gap-2">
            <Button type="button" onClick={() => onOpenChange(false)}>
              {t("cancel")}
            </Button>
            <Button type="submit" variant="primary">
              {t("createCaseAction")}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog.Root>
  );
}

export function Breadcrumbs({ page }: { page: string }) {
  const { t } = useI18n();
  const { space } = useDesk();
  return (
    <nav aria-label={t("breadcrumbs")} className="text-sm text-muted">
      <ol className="flex flex-wrap items-center gap-1">
        <li>{t("spaces")}</li>
        <li aria-hidden="true">/</li>
        <li>
          <Link href="/queues/unclaimed" className="hover:underline">
            {space.name}
          </Link>
        </li>
        <li aria-hidden="true">/</li>
        <li className="text-text">{page}</li>
      </ol>
    </nav>
  );
}

export function PageBody({ children }: { children: React.ReactNode }) {
  return <div className="grid gap-4 p-4 md:p-6">{children}</div>;
}
