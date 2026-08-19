import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '../supabase';
import TrendChart from './TrendChart';

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
