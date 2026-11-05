"use client";

import { useEffect, useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import { Button } from "@/components/ui/button";
import { DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { OPERATOR, spaceTypeLabel, type SpaceDetails, type SpaceIcon, type SpaceType } from "@/lib/desk";
import { cn } from "@/lib/utils";
import * as Dialog from "@radix-ui/react-dialog";

import { LowestPriorityIcon, PriorityIcon, SpaceGlyph, StatusLozenge } from "./bits";
import { useDesk } from "./desk-store";
import { Breadcrumbs, PageBody } from "./shell";

const ICONS: SpaceIcon[] = ["station", "shield", "heart", "scale", "home"];
const TYPES: SpaceType[] = ["police", "ngo", "shelter", "health", "legal"];

export function SettingsView({ section }: { section: string }) {
  const { t } = useI18n();
  const title =
    section === "people"
      ? t("people")
      : section === "permissions"
        ? t("permissions")
        : section === "workflow"
          ? t("workflow")
          : section === "notifications"
            ? t("notifications")
            : section === "language"
              ? t("language")
              : t("details");

  useEffect(() => {
    document.title = `${title} · Kasat Desk`;
  }, [title]);

  return (
    <PageBody>
      <Breadcrumbs page={title} />
      <h1 className="text-xl font-semibold">{title}</h1>
      {section === "people" ? (
        <People />
      ) : section === "permissions" ? (
        <SummaryCards
          cards={[
            [t("rolesNow"), t("rolesNowBody")],
            [t("statusesNow"), t("statusesNowBody")],
          ]}
        />
      ) : section === "workflow" ? (
        <Workflow />
      ) : section === "notifications" ? (
        <SummaryCards cards={[[t("emailNow"), t("emailNowBody")]]} />
      ) : section === "language" ? (
        <LanguageCard />
      ) : (
        <DetailsForm />
      )}
    </PageBody>
  );
}

function DetailsForm() {
  const { t } = useI18n();
  const { space, saveSpace } = useDesk();
  const [draft, setDraft] = useState<SpaceDetails>(space);
  const [saved, setSaved] = useState(false);
  useEffect(() => setDraft(space), [space]);
  const dirty = JSON.stringify(draft) !== JSON.stringify(space);
  const keyOk = /^[A-Z]{2,5}$/.test(draft.key);

  return (
    <form
      className="mx-auto grid w-full max-w-[480px] gap-3"
      onSubmit={(event) => {
        event.preventDefault();
        if (!dirty || !keyOk) return;
        saveSpace(draft);
        setSaved(true);
      }}
    >
      <label className="grid gap-1 text-sm">
        {t("spaceIcon")}
        <span className="flex gap-2">
          {ICONS.map((icon) => (
            <button
              key={icon}
              type="button"
              aria-label={icon}
              aria-pressed={draft.icon === icon}
              className={cn(
                "inline-flex h-8 w-8 items-center justify-center rounded-[6px] border",
                draft.icon === icon ? "border-primary" : "border-border",
              )}
              onClick={() => setDraft({ ...draft, icon })}
            >
              <SpaceGlyph icon={icon} />
            </button>
          ))}
        </span>
      </label>
      <Text label={t("spaceName")} value={draft.name} onChange={(name) => setDraft({ ...draft, name })} />
      <label className="grid gap-1 text-sm">
        {t("spaceKey")}
        <input
          value={draft.key}
          onChange={(event) => setDraft({ ...draft, key: event.target.value.toUpperCase() })}
          className="h-8 rounded-[6px] border border-border bg-bg px-2"
          pattern="[A-Z]{2,5}"
          required
        />
        <span className="text-xs text-muted">{t("spaceKeyHint")}</span>
      </label>
      <label className="grid gap-1 text-sm">
        {t("spaceType")}
        <select
          value={draft.type}
          onChange={(event) => setDraft({ ...draft, type: event.target.value as SpaceType })}
          className="h-8 rounded-[6px] border border-border bg-bg px-2"
        >
          {TYPES.map((type) => (
            <option key={type} value={type}>
              {spaceTypeLabel(type, t)}
            </option>
          ))}
        </select>
      </label>
      <Text label={t("region")} value={draft.region} onChange={(region) => setDraft({ ...draft, region })} />
      <label className="grid gap-1 text-sm">
        {t("descriptionField")}
        <textarea
          value={draft.description}
          onChange={(event) => setDraft({ ...draft, description: event.target.value })}
          className="min-h-24 rounded-[6px] border border-border bg-bg p-2"
        />
      </label>
      <Text label={t("spaceLead")} value={draft.lead} onChange={(lead) => setDraft({ ...draft, lead })} />
      <Text
        label={t("defaultAssignee")}
        value={draft.defaultAssignee}
        onChange={(defaultAssignee) => setDraft({ ...draft, defaultAssignee })}
      />
      <div className="flex items-center gap-3">
        <Button type="submit" variant="primary" disabled={!dirty || !keyOk}>
          {t("save")}
        </Button>
        {saved && !dirty ? <span className="text-sm text-success">{t("saved")}</span> : null}
      </div>
    </form>
  );
}

function Text({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) {
  return (
    <label className="grid gap-1 text-sm">
      {label}
      <input value={value} onChange={(event) => onChange(event.target.value)} className="h-8 rounded-[6px] border border-border bg-bg px-2" />
    </label>
  );
}

function People() {
  const { t } = useI18n();
  const [tab, setTab] = useState<"users" | "requests">("users");
  const [open, setOpen] = useState(false);
  return (
    <div className="grid gap-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex gap-2">
          <Button variant={tab === "users" ? "primary" : "outline"} onClick={() => setTab("users")}>
            {t("currentUsers")}
          </Button>
          <Button variant={tab === "requests" ? "primary" : "outline"} onClick={() => setTab("requests")}>
            {t("accessRequests")}
          </Button>
        </div>
        <Button onClick={() => setOpen(true)}>{t("addPeople")}</Button>
      </div>
      {tab === "requests" ? (
        <p className="rounded-[6px] border border-dashed border-border bg-bg px-4 py-8 text-center text-sm text-muted">{t("noRequests")}</p>
      ) : (
        <div className="overflow-x-auto rounded-[6px] border border-border bg-bg">
          <table className="w-full min-w-[640px] text-left text-sm">
            <thead>
              <tr className="border-b border-border text-xs text-muted">
                <th className="px-3 py-2 font-medium">{t("name")}</th>
                <th className="px-3 py-2 font-medium">{t("email")}</th>
                <th className="px-3 py-2 font-medium">{t("role")}</th>
                <th className="px-3 py-2 font-medium">{t("action")}</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td className="px-3 py-2">{OPERATOR.name}</td>
                <td className="px-3 py-2">{OPERATOR.email}</td>
                <td className="px-3 py-2">{t("roleAdmin")}</td>
                <td className="px-3 py-2">
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <span tabIndex={0} className="inline-flex">
                        <Button size="sm" disabled>
                          {t("remove")}
                        </Button>
                      </span>
                    </TooltipTrigger>
                    <TooltipContent>{t("cannotRemoveSelf")}</TooltipContent>
                  </Tooltip>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      )}
      <Dialog.Root open={open} onOpenChange={setOpen}>
        <DialogContent closeLabel={t("close")}>
          <DialogTitle className="pr-8 text-base font-semibold">{t("addPeople")}</DialogTitle>
          <DialogDescription className="mt-1 text-sm text-muted">{t("inviteSoon")}</DialogDescription>
          <form className="mt-4 grid gap-3" onSubmit={(event) => event.preventDefault()}>
            <Text label={t("email")} value="" onChange={() => undefined} />
            <label className="grid gap-1 text-sm">
              {t("role")}
              <select className="h-8 rounded-[6px] border border-border bg-bg px-2" defaultValue="agent">
                <option value="space_admin">{t("roleAdmin")}</option>
                <option value="agent">{t("roleAgent")}</option>
                <option value="viewer">{t("roleViewer")}</option>
              </select>
            </label>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="inline-flex w-fit" tabIndex={0}>
                  <Button disabled>{t("invite")}</Button>
                </span>
              </TooltipTrigger>
              <TooltipContent>{t("inviteSoon")}</TooltipContent>
            </Tooltip>
          </form>
        </DialogContent>
      </Dialog.Root>
    </div>
  );
}

function SummaryCards({ cards }: { cards: [string, string][] }) {
  return (
    <div className="mx-auto grid w-full max-w-[480px] gap-3">
      {cards.map(([title, body]) => (
        <section key={title} className="rounded-[6px] border border-border bg-bg p-3">
          <h2 className="text-sm font-semibold">{title}</h2>
          <p className="mt-1 text-sm text-muted">{body}</p>
        </section>
      ))}
    </div>
  );
}

function Workflow() {
  const { t } = useI18n();
  return (
    <div className="mx-auto grid w-full max-w-[480px] gap-3">
      <section className="rounded-[6px] border border-border bg-bg p-3">
        <h2 className="text-sm font-semibold">{t("workflow")}</h2>
        <p className="mt-1 text-sm text-muted">{t("workflowIntro")}</p>
        <ul className="mt-3 grid gap-2 text-sm">
          <li>{t("transitionClaim")}</li>
          <li>{t("transitionResolve")}</li>
        </ul>
        <div className="mt-3 flex flex-wrap gap-2">
          <StatusLozenge status="new" />
          <StatusLozenge status="progress" />
          <StatusLozenge status="resolved" />
        </div>
      </section>
      <section className="rounded-[6px] border border-border bg-bg p-3">
        <h2 className="text-sm font-semibold">{t("notEnabled")}</h2>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <StatusLozenge status="claimed" />
          <StatusLozenge status="waiting" />
          <StatusLozenge status="referred" />
          <StatusLozenge status="closed" />
        </div>
        <div className="mt-3 flex items-center gap-2">
          <PriorityIcon priority="P1" />
          <PriorityIcon priority="P2" />
          <PriorityIcon priority="P3" />
          <PriorityIcon priority="P4" />
          <LowestPriorityIcon />
        </div>
      </section>
    </div>
  );
}

function LanguageCard() {
  const { t, locale, setLocale } = useI18n();
  return (
    <div className="mx-auto grid w-full max-w-[480px] gap-3">
      <SummaryCards cards={[[t("languagesNow"), t("languagesNowBody")]]} />
      <fieldset className="grid gap-2 rounded-[6px] border border-border bg-bg p-3">
        <legend className="px-1 text-sm font-semibold">{t("displayLanguage")}</legend>
        <p className="text-sm text-muted">{t("displayLanguageHelp")}</p>
        <label className="flex items-center gap-2 text-sm">
          <input type="radio" name="locale" checked={locale === "en"} onChange={() => setLocale("en")} />
          {t("english")}
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input type="radio" name="locale" checked={locale === "am"} onChange={() => setLocale("am")} />
          {t("amharic")}
        </label>
      </fieldset>
    </div>
  );
}

export function AccountPage({ kind }: { kind: "profile" | "settings" }) {
  const { t } = useI18n();
  const title = kind === "profile" ? t("profile") : t("accountSettings");
  useEffect(() => {
    document.title = `${title} · Kasat Desk`;
  }, [title]);
  return (
    <PageBody>
      <Breadcrumbs page={title} />
      <h1 className="text-xl font-semibold">{title}</h1>
      <section className="mx-auto grid w-full max-w-[480px] gap-2 rounded-[6px] border border-border bg-bg p-3 text-sm">
        <p className="text-muted">{kind === "profile" ? t("profileIntro") : t("accountIntro")}</p>
        <p>
          <span className="text-muted">{t("name")}: </span>
          {OPERATOR.name}
        </p>
        <p>
          <span className="text-muted">{t("email")}: </span>
          {OPERATOR.email}
        </p>
        <p>
          <span className="text-muted">{t("space")}: </span>
          {t("orgName")}
        </p>
      </section>
    </PageBody>
  );
}

export function ReportsView() {
  const { t } = useI18n();
  const { incidents } = useDesk();
  useEffect(() => {
    document.title = `${t("reports")} · Kasat Desk`;
  }, [t]);
  const open = incidents.filter((item) => item.status !== "RESOLVED").length;
  return (
    <PageBody>
      <Breadcrumbs page={t("reports")} />
      <h1 className="text-xl font-semibold">{t("reports")}</h1>
      <p className="text-sm text-muted">{t("reportsIntro")}</p>
      <div className="grid max-w-[480px] grid-cols-3 gap-2">
        <Stat label={t("totalCases")} value={incidents.length} />
        <Stat label={t("openCases")} value={open} />
        <Stat label={t("queueResolved")} value={incidents.length - open} />
      </div>
    </PageBody>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-[6px] border border-border bg-bg p-3">
      <p className="text-xs text-muted">{label}</p>
      <p className="text-xl font-semibold">{value}</p>
    </div>
  );
}

export function AccessLogView() {
  const { t } = useI18n();
  const { log } = useDesk();
  useEffect(() => {
    document.title = `${t("accessLog")} · Kasat Desk`;
  }, [t]);
  const label = {
    claim: t("actionClaim"),
    resolve: t("actionResolve"),
    location_view: t("actionLocation"),
    create: t("actionCreate"),
  };
  return (
    <PageBody>
      <Breadcrumbs page={t("accessLog")} />
      <h1 className="text-xl font-semibold">{t("accessLog")}</h1>
      <p className="text-sm text-muted">{t("accessIntro")}</p>
      {log.length === 0 ? (
        <p className="rounded-[6px] border border-dashed border-border bg-bg px-4 py-8 text-center text-sm text-muted">{t("accessEmpty")}</p>
      ) : (
        <div className="overflow-x-auto rounded-[6px] border border-border bg-bg">
          <table className="w-full min-w-[720px] text-left text-sm">
            <thead>
              <tr className="border-b border-border text-xs text-muted">
                <th className="px-3 py-2 font-medium">{t("when")}</th>
                <th className="px-3 py-2 font-medium">{t("who")}</th>
                <th className="px-3 py-2 font-medium">{t("what")}</th>
                <th className="px-3 py-2 font-medium">{t("case")}</th>
              </tr>
            </thead>
            <tbody>
              {[...log].reverse().map((event) => (
                <tr key={event.id} className="border-b border-border last:border-0">
                  <td className="px-3 py-2">{event.at}</td>
                  <td className="px-3 py-2">{event.actor}</td>
                  <td className="px-3 py-2">{label[event.action]}</td>
                  <td className="px-3 py-2">{event.trackingId}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </PageBody>
  );
}
