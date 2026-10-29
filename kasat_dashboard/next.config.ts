import type { NextConfig } from "next";

const config: NextConfig = {
  reactStrictMode: true,
  // The dashboard renders survivor payloads. Nothing here should be indexed,
  // embedded, or referred out with a referrer header.
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Robots-Tag", value: "noindex, nofollow" },
          { key: "Referrer-Policy", value: "no-referrer" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
        ],
      },
    ];
  },
};

export default config;
