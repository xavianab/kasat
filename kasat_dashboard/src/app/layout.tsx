import type { Metadata } from "next";
import { Inter, Noto_Sans_Ethiopic } from "next/font/google";
import { ThemeProvider } from "next-themes";

import { I18nProvider } from "@/components/i18n-provider";
import { TooltipProvider } from "@/components/ui/tooltip";

import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const ethiopic = Noto_Sans_Ethiopic({
  subsets: ["ethiopic"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-ethiopic",
});

export const metadata: Metadata = {
  title: "Kasat Desk",
  description: "Kasat Desk for authorized staff.",
  robots: { index: false, follow: false },
  icons: { icon: "/brand/kasat-bloom.svg" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning className={`${inter.variable} ${ethiopic.variable}`}>
      <body className="min-h-screen bg-surface font-sans text-text antialiased">
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem storageKey="kasat.desk.theme">
          <I18nProvider>
            <TooltipProvider delayDuration={300}>{children}</TooltipProvider>
          </I18nProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
