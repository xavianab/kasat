import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Kasat Dispatch",
  description: "Operator triage for anonymous incident reports.",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="topbar">
          <span className="wordmark">KASAT</span>
          <span className="badge" style={{ color: "var(--faint)" }}>
            DISPATCH
          </span>
          <span style={{ flex: 1 }} />
          <span className="badge" style={{ color: "var(--accent)" }}>
            <span className="dot" />
            LIVE
          </span>
        </header>
        <main className="shell">{children}</main>
      </body>
    </html>
  );
}
