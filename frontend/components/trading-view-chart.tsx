"use client"

import { useEffect, useRef } from "react"

export default function TradingViewChart() {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    // TradingView Widget Script
    const script = document.createElement("script")
    script.src = "https://s3.tradingview.com/tv.js"
    script.async = true
    script.onload = () => {
      if (containerRef.current && typeof window !== "undefined" && (window as any).TradingView) {
        ;new (window as any).TradingView.widget({
          autosize: true,
          symbol: "NASDAQ:AAPL",
          interval: "D",
          timezone: "Etc/UTC",
          theme: "dark",
          style: "1",
          locale: "en",
          toolbar_bg: "#0a0a0f",
          enable_publishing: false,
          allow_symbol_change: true,
          container_id: "tradingview_chart",
          hide_top_toolbar: false,
          hide_side_toolbar: false,
          save_image: false,
          backgroundColor: "#0a0a0f",
          gridColor: "rgba(255, 255, 255, 0.06)",
        })
      }
    }
    document.head.appendChild(script)

    return () => {
      if (document.head.contains(script)) {
        document.head.removeChild(script)
      }
    }
  }, [])

  return (
    <div className="h-full w-full bg-card">
      <div id="tradingview_chart" ref={containerRef} className="h-full w-full" />
    </div>
  )
}
