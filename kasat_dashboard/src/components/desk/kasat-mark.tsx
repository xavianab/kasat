"use client";

import { useId } from "react";

import { kasatBloomSvg } from "./kasat-bloom-markup";

/** Kasat flower, inlined so each copy gets its own gradient ids. */
export function KasatMark({ size = 22 }: { size?: number }) {
  const id = useId().replace(/:/g, "");
  const markup = kasatBloomSvg
    .replace('width="200"', 'width="100%"')
    .replace('height="200"', 'height="100%"')
    .replaceAll('id="pf"', `id="${id}pf"`)
    .replaceAll("url(#pf)", `url(#${id}pf)`)
    .replaceAll('id="pb"', `id="${id}pb"`)
    .replaceAll("url(#pb)", `url(#${id}pb)`);

  return (
    <span
      aria-hidden="true"
      className="inline-flex shrink-0"
      style={{ width: size, height: size }}
      dangerouslySetInnerHTML={{ __html: markup }}
    />
  );
}
