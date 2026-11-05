"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

import { messagesByLocale, type Locale, type Messages } from "@/lib/messages";
import { fill } from "@/lib/utils";

type I18nValue = {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: (key: keyof Messages, vars?: Record<string, string | number>) => string;
};

const I18nContext = createContext<I18nValue | null>(null);
const STORAGE_KEY = "kasat.desk.locale";

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("en");

  useEffect(() => {
    const saved = window.localStorage.getItem(STORAGE_KEY);
    if (saved === "en" || saved === "am") setLocaleState(saved);
  }, []);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    window.localStorage.setItem(STORAGE_KEY, next);
  }, []);

  const t = useCallback(
    (key: keyof Messages, vars?: Record<string, string | number>) => fill(messagesByLocale[locale][key], vars),
    [locale],
  );

  const value = useMemo(() => ({ locale, setLocale, t }), [locale, setLocale, t]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const value = useContext(I18nContext);
  if (!value) throw new Error("useI18n must be used inside I18nProvider");
  return value;
}
