import React, { useState } from 'react';

export default function Reports() {
  const [selectedVariant, setSelectedVariant] = useState('DataPro'); // DataPro, ModernMinimal, VisualFirst

  const metrics = {
    revenue: '$124,500',
    volume: '842 Tons',
    co2: '14B kg',
    efficiency: '96.2%',
  };

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

      {/* ── Dynamic Layout based on Selected Variant ── */}

      {/* 1. DATA PRO VARIANT (Structured, Table/List Heavy) */}
      {selectedVariant === 'DataPro' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div className="metrics-grid">
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">Gross Revenue</span>
              <span className="metric-value">{metrics.revenue}</span>
            </div>
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">Volume Collected</span>
              <span className="metric-value">{metrics.volume}</span>
            </div>
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">CO2 Offset Total</span>
              <span className="metric-value">{metrics.co2}</span>
            </div>
            <div className="card-glass metric-card" style={{ background: 'var(--bg-card)' }}>
              <span className="metric-title">Fleet Efficiency</span>
              <span className="metric-value" style={{ color: 'var(--color-success)' }}>{metrics.efficiency}</span>
            </div>
          </div>

          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontSize: '16px' }}>Detailed Volume Growth & Trends</h3>
            <div style={{ position: 'relative', width: '100%', height: '240px', background: 'var(--bg-app)', borderRadius: '12px' }}>
              <svg viewBox="0 0 500 200" width="100%" height="100%" preserveAspectRatio="none">
                <path d="M 0 160 Q 80 120 150 140 T 300 60 T 450 30 T 500 20 L 500 200 L 0 200 Z" fill="rgba(6, 182, 212, 0.15)" />
                <path d="M 0 160 Q 80 120 150 140 T 300 60 T 450 30 T 500 20" fill="none" stroke="var(--color-info)" strokeWidth="3" />
                <circle cx="150" cy="140" r="4" fill="var(--color-info)" />
                <circle cx="300" cy="60" r="4" fill="var(--color-info)" />
                <circle cx="450" cy="30" r="4" fill="var(--color-info)" />
              </svg>
            </div>
          </div>
        </div>
      )}

      {/* 2. MODERN MINIMAL VARIANT (Minimalist spacing, sleek thin lines) */}
      {selectedVariant === 'ModernMinimal' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div style={{ borderBottom: '1px solid var(--border-divider)', paddingBottom: '20px' }}>
            <span style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontWeight: 'bold' }}>Performance Story</span>
            <p style={{ fontSize: '15px', color: 'var(--text-primary)', marginTop: '8px', lineHeight: '160%', maxWidth: '800px' }}>
              Revenue growth continues to outpace vehicle distance, indicating improved operational efficiency and a shift towards higher-yielding recycling collection agreements.
            </p>
          </div>

          <div className="metrics-grid" style={{ gap: '40px' }}>
            <div>
              <span className="metric-title" style={{ fontSize: '11px' }}>Net Revenue</span>
              <p style={{ fontSize: '36px', fontWeight: '800', marginTop: '6px' }}>{metrics.revenue}</p>
            </div>
            <div>
              <span className="metric-title" style={{ fontSize: '11px' }}>Waste Volume</span>
              <p style={{ fontSize: '36px', fontWeight: '800', marginTop: '6px' }}>{metrics.volume}</p>
            </div>
            <div>
              <span className="metric-title" style={{ fontSize: '11px' }}>Carbon Savings</span>
              <p style={{ fontSize: '36px', fontWeight: '800', marginTop: '6px' }}>{metrics.co2}</p>
            </div>
          </div>

          <div style={{ height: '200px', width: '100%', position: 'relative', marginTop: '20px' }}>
            <svg viewBox="0 0 500 100" width="100%" height="100%" preserveAspectRatio="none">
              <path d="M 0 80 L 100 70 L 200 75 L 300 40 L 400 30 L 500 15" fill="none" stroke="var(--color-primary)" strokeWidth="2" />
            </svg>
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
                <p style={{ fontSize: '40px', fontWeight: '800', marginTop: '4px' }}>{metrics.revenue}</p>
              </div>
              <div>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', color: 'rgba(255,255,255,0.7)', fontWeight: 'bold' }}>CO2 Equivalents Offset</span>
                <p style={{ fontSize: '40px', fontWeight: '800', marginTop: '4px' }}>{metrics.co2}</p>
              </div>
            </div>
          </div>

          <div className="card-glass" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <h3 style={{ fontSize: '16px' }}>Volume Trends</h3>
            <div style={{ position: 'relative', width: '100%', height: '240px' }}>
              <svg viewBox="0 0 500 200" width="100%" height="100%" preserveAspectRatio="none">
                <path d="M 0 180 C 100 160, 200 90, 300 100 C 400 110, 450 50, 500 20" fill="none" stroke="var(--color-primary)" strokeWidth="4" />
                <path d="M 0 180 C 100 160, 200 90, 300 100 C 400 110, 450 50, 500 20 L 500 200 L 0 200 Z" fill="rgba(2, 132, 199, 0.1)" />
              </svg>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
