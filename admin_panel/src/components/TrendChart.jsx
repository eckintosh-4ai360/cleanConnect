import React, { useMemo, useRef, useState } from 'react';

// ── Reusable trend chart: single-series line + area with a hover crosshair
// and tooltip, driven entirely by real Postgres data (no fixtures). ───────
export default function TrendChart({ points, color, height = 240, showArea = true }) {
  const plotRef = useRef(null);
  const [hoverIndex, setHoverIndex] = useState(null);
  const gradientId = useRef(`trend-grad-${Math.random().toString(36).slice(2)}`).current;

  const n = points.length;
  const values = points.map((p) => p.weightKg);
  const maxVal = Math.max(...values, 1);
  const hasData = values.some((v) => v > 0);

  const padTop = 20;
  const padBottom = 20;
  const plotHeight = 200 - padTop - padBottom;

  const coords = points.map((p, i) => ({
    x: n > 1 ? (i / (n - 1)) * 500 : 250,
    y: padTop + plotHeight - (p.weightKg / maxVal) * plotHeight,
  }));

  const linePath = coords
    .map((c, i) => `${i === 0 ? 'M' : 'L'} ${c.x.toFixed(1)} ${c.y.toFixed(1)}`)
    .join(' ');
  const areaPath = n > 0 ? `${linePath} L ${coords[n - 1].x.toFixed(1)} 200 L 0 200 Z` : '';

  const labelIdxs = useMemo(() => {
    if (n <= 1) return [0];
    const count = Math.min(5, n);
    const idxs = new Set();
    for (let i = 0; i < count; i++) idxs.add(Math.round((i / (count - 1)) * (n - 1)));
    return Array.from(idxs).sort((a, b) => a - b);
  }, [n]);

  const handleMove = (e) => {
    if (n === 0 || !plotRef.current) return;
    const rect = plotRef.current.getBoundingClientRect();
    const fraction = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
    setHoverIndex(Math.round(fraction * (n - 1)));
  };

  const fmtShortDate = (d) => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const hoverX = hoverIndex != null ? (hoverIndex / Math.max(1, n - 1)) * 100 : null;
  const hoverY = hoverIndex != null && coords[hoverIndex] ? (coords[hoverIndex].y / 200) * 100 : null;

  return (
    <div style={{ width: '100%' }}>
      <div
        ref={plotRef}
        onMouseMove={handleMove}
        onMouseLeave={() => setHoverIndex(null)}
        role="img"
        aria-label={`Waste volume trend over the last ${n} periods, peaking at ${maxVal.toFixed(1)} kg`}
        style={{ position: 'relative', width: '100%', height: `${height}px`, background: 'var(--bg-app)', borderRadius: '12px' }}
      >
        <svg viewBox="0 0 500 200" width="100%" height="100%" preserveAspectRatio="none" style={{ display: 'block' }}>
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity="0.22" />
              <stop offset="100%" stopColor={color} stopOpacity="0" />
            </linearGradient>
          </defs>
          {showArea && n > 0 && <path d={areaPath} fill={`url(#${gradientId})`} stroke="none" />}
          {n > 0 && <path d={linePath} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />}
          {n > 0 && (
            <circle cx={coords[n - 1].x} cy={coords[n - 1].y} r="4" fill={color} stroke="var(--bg-app)" strokeWidth="2" />
          )}
          {hoverIndex != null && coords[hoverIndex] && (
            <circle cx={coords[hoverIndex].x} cy={coords[hoverIndex].y} r="5" fill={color} stroke="var(--bg-app)" strokeWidth="2" />
          )}
        </svg>

        {hoverIndex != null && (
          <div
            style={{
              position: 'absolute',
              top: 0,
              bottom: 0,
              left: `${hoverX}%`,
              width: '1px',
              background: 'var(--border-divider)',
              pointerEvents: 'none',
            }}
          />
        )}

        {hoverIndex != null && points[hoverIndex] && (
          <div
            style={{
              position: 'absolute',
              left: `${hoverX}%`,
              top: `${hoverY}%`,
              transform: `translate(${hoverIndex === 0 ? '4px' : hoverIndex === n - 1 ? 'calc(-100% - 4px)' : '-50%'}, -130%)`,
              background: 'var(--bg-card-hover)',
              border: '1px solid var(--border-divider)',
              borderRadius: '8px',
              padding: '6px 10px',
              fontSize: '11px',
              whiteSpace: 'nowrap',
              pointerEvents: 'none',
              boxShadow: '0 4px 12px rgba(0,0,0,0.16)',
              zIndex: 2,
            }}
          >
            <div style={{ color: 'var(--text-secondary)' }}>{fmtShortDate(points[hoverIndex].date)}</div>
            <div style={{ color: 'var(--text-primary)', fontWeight: 700 }}>
              {points[hoverIndex].weightKg.toFixed(1)} kg
            </div>
          </div>
        )}

        {!hasData && (
          <div
            style={{
              position: 'absolute',
              inset: 0,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '12px',
              color: 'var(--text-muted)',
            }}
          >
            No collections recorded in this period yet.
          </div>
        )}
      </div>

      <div style={{ position: 'relative', height: '18px', marginTop: '6px' }}>
        {labelIdxs.map((idx) => (
          <span
            key={idx}
            style={{
              position: 'absolute',
              left: `${(idx / Math.max(1, n - 1)) * 100}%`,
              transform: idx === 0 ? 'translateX(0)' : idx === n - 1 ? 'translateX(-100%)' : 'translateX(-50%)',
              fontSize: '10px',
              color: 'var(--text-secondary)',
            }}
          >
            {fmtShortDate(points[idx].date)}
          </span>
        ))}
      </div>
    </div>
  );
}
