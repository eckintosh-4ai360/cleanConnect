import React, { useState, useEffect, useMemo, useRef } from 'react';
import { supabase } from '../supabase';

const DAY_MS = 24 * 60 * 60 * 1000;
const TREND_DAYS = 14;

const dayKey = (date) =>
  `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;

const buildEmptyTrend = (days) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const out = [];
  for (let i = days - 1; i >= 0; i--) {
    out.push({ date: new Date(today.getTime() - i * DAY_MS), weightKg: 0 });
  }
  return out;
};

export default function Reports() {
  const [selectedVariant, setSelectedVariant] = useState('DataPro'); // DataPro, ModernMinimal, VisualFirst
  const [loading, setLoading] = useState(true);
  const [metrics, setMetrics] = useState({
    revenue: 0,
    volumeKg: 0,
    co2Kg: 0,
    efficiencyPct: 0,
  });
  const [trend, setTrend] = useState(() => buildEmptyTrend(TREND_DAYS));

  // ── Gross Revenue: live sum of paid invoices ────────────────────────────
  useEffect(() => {
    let mounted = true;

    const fetchRevenue = async () => {
      const { data, error } = await supabase.from('payments').select('amount').eq('status', 'paid');
      if (mounted && !error) {
        const total = data.reduce((s, d) => s + (d.amount ?? 0), 0);
        setMetrics((prev) => ({ ...prev, revenue: total }));
      }
    };
    fetchRevenue();

    const channel = supabase
      .channel('reports_payments_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'payments' }, fetchRevenue)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  // ── Collections: live volume trend (last N days) + all-time volume/CO2/efficiency totals ──
  useEffect(() => {
    let mounted = true;

    const fetchCollections = async () => {
      const { data, error } = await supabase
        .from('collection_events')
        .select('weight_kg, carbon_offset, status, collected_at')
        .order('collected_at', { ascending: false });

      if (!mounted || error) {
        if (error) console.warn('Reports collection_events fetch:', error);
        setLoading(false);
        return;
      }

      const buckets = new Map();
      data.forEach((d) => {
        const collectedAt = d.collected_at ? new Date(d.collected_at) : null;
        if (!collectedAt) return;
        const key = dayKey(collectedAt);
        buckets.set(key, (buckets.get(key) ?? 0) + (d.weight_kg ?? 0));
      });

      setTrend(
        buildEmptyTrend(TREND_DAYS).map((d) => ({
          date: d.date,
          weightKg: buckets.get(dayKey(d.date)) ?? 0,
        }))
      );

      const totalWeight = data.reduce((s, d) => s + (d.weight_kg ?? 0), 0);
      const totalCO2 = data.reduce((s, d) => s + (d.carbon_offset ?? 0), 0);
      const completedCount = data.filter((d) => d.status === 'completed').length;
      setMetrics((prev) => ({
        ...prev,
        volumeKg: totalWeight,
        co2Kg: totalCO2,
        efficiencyPct: data.length > 0 ? (completedCount / data.length) * 100 : 0,
      }));
      setLoading(false);
    };
    fetchCollections();

    const channel = supabase
      .channel('reports_collection_events_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'collection_events' }, fetchCollections)
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, []);

  // ── Format helpers ──────────────────────────────────────────────────────
  const formatCurrency = (val) =>
    `GHS ${val.toLocaleString('en-US', { maximumFractionDigits: 0 })}`;
  const formatWeight = (kg) =>
    kg >= 1000 ? `${(kg / 1000).toFixed(1)} Tons` : `${kg.toFixed(1)} kg`;
  const formatCO2 = (kg) => `${kg.toFixed(1)} kg`;
  const formatPct = (p) => `${p.toFixed(1)}%`;

  const metricsDisplay = {
    revenue: loading ? '—' : formatCurrency(metrics.revenue),
    volume: loading ? '—' : formatWeight(metrics.volumeKg),
    co2: loading ? '—' : formatCO2(metrics.co2Kg),
    efficiency: loading ? '—' : formatPct(metrics.efficiencyPct),
  };

  // ── Data-driven narrative for the Modern Minimal variant ────────────────
  const trendSummary = useMemo(() => {
    const half = Math.floor(trend.length / 2);
    const firstHalf = trend.slice(0, half).reduce((s, p) => s + p.weightKg, 0);
    const secondHalf = trend.slice(half).reduce((s, p) => s + p.weightKg, 0);

    if (firstHalf === 0 && secondHalf === 0) {
      return 'No collection activity recorded yet — this story will populate as pickups are completed and logged.';
    }
    const pct = firstHalf === 0 ? 100 : ((secondHalf - firstHalf) / firstHalf) * 100;
    if (pct > 2) {
      return `Waste volume collected is up ${pct.toFixed(0)}% over the last ${TREND_DAYS} days, pointing to improved operational throughput and stronger collection coverage.`;
    }
    if (pct < -2) {
      return `Waste volume collected is down ${Math.abs(pct).toFixed(0)}% over the last ${TREND_DAYS} days — worth a look at scheduling or rider coverage.`;
    }
    return `Waste volume collected has held steady over the last ${TREND_DAYS} days, with no significant swing in operational throughput.`;
  }, [trend]);

  return (
    <div className="page-content">
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px' }}>Analytics & Impact Reports</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Toggle analytics variations to audit volume statistics and carbon savings.
          </p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--color-success)', display: 'inline-block' }} />
            <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: 'bold' }}>
              Live
            </span>
          </div>

          {/* Analytical variant selector */}
          <div style={{ display: 'flex', background: 'var(--bg-card)', padding: '4px', borderRadius: '8px', border: '1px solid var(--border-divider)' }}>
            <button
              className="btn-outline"
              style={{ border: 'none', background: selectedVariant === 'ModernMinimal' ? 'var(--color-primary)' : 'transparent', color: selectedVariant === 'ModernMinimal' ? 'white' : 'var(--text-primary)', padding: '6px 14px', fontSize: '11px' }}
              onClick={() => setSelectedVariant('ModernMinimal')}
            >
              Modern Minimal
            </button>
            <button
              className="btn-outline"
              style={{ border: 'none', background: selectedVariant === 'VisualFirst' ? 'var(--color-primary)' : 'transparent', color: selectedVariant === 'VisualFirst' ? 'white' : 'var(--text-primary)', padding: '6px 14px', fontSize: '11px' }}
              onClick={() => setSelectedVariant('VisualFirst')}
            >
              Visual First
            </button>
            <button
              className="btn-outline"
              style={{ border: 'none', background: selectedVariant === 'DataPro' ? 'var(--color-primary)' : 'transparent', color: selectedVariant === 'DataPro' ? 'white' : 'var(--text-primary)', padding: '6px 14px', fontSize: '11px' }}
              onClick={() => setSelectedVariant('DataPro')}
            >
              Data Pro
            </button>
          </div>
        </div>
      </div>

      {/* ── Dynamic Layout based on Selected Variant ── */}

      {/* 1. DATA PRO VARIANT (Structured, Table/List Heavy) */}
      {selectedVariant === 'DataPro' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div className="metrics-grid">
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">Gross Revenue</span>
              <span className="metric-value">{metricsDisplay.revenue}</span>
            </div>
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">Volume Collected</span>
              <span className="metric-value">{metricsDisplay.volume}</span>
            </div>
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">CO2 Offset Total</span>
              <span className="metric-value">{metricsDisplay.co2}</span>
            </div>
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">Fleet Efficiency</span>
              <span className="metric-value" style={{ color: 'var(--color-success)' }}>{metricsDisplay.efficiency}</span>
            </div>
          </div>

          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontSize: '16px' }}>Detailed Volume Growth & Trends</h3>
            <TrendChart points={trend} color="var(--color-info)" height={240} />
          </div>
        </div>
      )}

      {/* 2. MODERN MINIMAL VARIANT (Minimalist spacing, sleek thin lines) */}
      {selectedVariant === 'ModernMinimal' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div style={{ borderBottom: '1px solid var(--border-divider)', paddingBottom: '20px' }}>
            <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontWeight: 'bold' }}>Performance Story</span>
            <p style={{ fontSize: '15px', color: 'var(--text-primary)', marginTop: '8px', lineHeight: '160%', maxWidth: '800px' }}>
              {trendSummary}
            </p>
          </div>

          <div className="metrics-grid" style={{ gap: '40px' }}>
            <div>
              <span className="metric-title" style={{ fontSize: '11px' }}>Net Revenue</span>
              <p style={{ fontSize: '36px', fontWeight: '800', marginTop: '6px' }}>{metricsDisplay.revenue}</p>
            </div>
            <div>
              <span className="metric-title" style={{ fontSize: '11px' }}>Waste Volume</span>
              <p style={{ fontSize: '36px', fontWeight: '800', marginTop: '6px' }}>{metricsDisplay.volume}</p>
            </div>
            <div>
              <span className="metric-title" style={{ fontSize: '11px' }}>Carbon Savings</span>
              <p style={{ fontSize: '36px', fontWeight: '800', marginTop: '6px' }}>{metricsDisplay.co2}</p>
            </div>
          </div>

          <div style={{ marginTop: '20px' }}>
            <TrendChart points={trend} color="var(--color-primary)" height={200} showArea={false} />
          </div>
        </div>
      )}

      {/* 3. VISUAL FIRST VARIANT (Big typography, block backgrounds, colorful grids) */}
      {selectedVariant === 'VisualFirst' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: '24px' }}>
          <div className="card-glass" style={{ background: 'linear-gradient(135deg, var(--color-primary), var(--color-info))', color: 'white', display: 'flex', flexDirection: 'column', gap: '20px', padding: '32px' }}>
            <h3 style={{ color: 'white', fontSize: '20px' }}>Impact Summary</h3>
            <p style={{ color: 'rgba(255, 255, 255, 0.8)', fontSize: '13px', lineHeight: '150%' }}>
              High-level overview of collection performance, logistics metrics, and environmental impact.
            </p>
            <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', color: 'rgba(255,255,255,0.7)', fontWeight: 'bold' }}>Revenue Collected</span>
                <p style={{ fontSize: '40px', fontWeight: '800', marginTop: '4px' }}>{metricsDisplay.revenue}</p>
              </div>
              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', color: 'rgba(255,255,255,0.7)', fontWeight: 'bold' }}>CO2 Equivalents Offset</span>
                <p style={{ fontSize: '40px', fontWeight: '800', marginTop: '4px' }}>{metricsDisplay.co2}</p>
              </div>
            </div>
          </div>

          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontSize: '16px' }}>Volume Trends</h3>
            <TrendChart points={trend} color="var(--color-primary)" height={240} />
          </div>
        </div>
      )}
    </div>
  );
}

// ── Reusable trend chart: single-series line + area with a hover crosshair
// and tooltip, driven entirely by real Postgres data (no fixtures). ───────
function TrendChart({ points, color, height = 240, showArea = true }) {
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
        aria-label={`Waste volume trend over the last ${n} days, peaking at ${maxVal.toFixed(1)} kg`}
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
