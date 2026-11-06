/**
 * WU Custom Reticle Studio - Zero-Build NUI Engine
 *
 * Features:
 * - 4 Standard Slots (Dot, Inner Cross, Outer Cross, Circle/Arc) + Up to 6 Custom Shape Layers
 * - Real-time SVG rendering on both the live HUD center overlay and 2.0x Zoom Preview
 * - Compact 1-line RT1:... differential share code encoder/decoder
 * - Personal preset management (Client KVP + Server Storage hybrid sync)
 * - Server-admin display mode enforcement (aim_only / armed / always / off)
 */
(function () {
  'use strict';

  const SVG_NS = 'http://www.w3.org/2000/svg';

  // DOM References
  const appEl = document.getElementById('app');
  const hudContainer = document.getElementById('hud-reticle-container');
  const hudSvg = document.getElementById('hud-reticle-svg');
  const centerGuide = document.getElementById('editor-center-guide');
  const previewStage = document.getElementById('preview-stage');
  const previewSvg = document.getElementById('preview-reticle-svg');

  const btnClose = document.getElementById('btn-close');
  const btnReset = document.getElementById('btn-reset');
  const btnApplyClose = document.getElementById('btn-apply-close');
  const btnAddLayer = document.getElementById('btn-add-layer');
  const btnCopyCode = document.getElementById('btn-copy-code');
  const btnImportCode = document.getElementById('btn-import-code');
  const btnSavePreset = document.getElementById('btn-save-preset');

  const inputGlobalScale = document.getElementById('input-global-scale');
  const valGlobalScale = document.getElementById('val-global-scale');
  const inputGlobalOpacity = document.getElementById('input-global-opacity');
  const valGlobalOpacity = document.getElementById('val-global-opacity');

  const inputShareCode = document.getElementById('input-share-code');
  const footerLiveCode = document.getElementById('footer-live-code');
  const inputPresetName = document.getElementById('input-preset-name');

  const standardSlotsContainer = document.getElementById('standard-slots-container');
  const customLayersContainer = document.getElementById('custom-layers-container');
  const displayModesList = document.getElementById('display-modes-list');
  const myPresetsList = document.getElementById('my-presets-list');
  const builtinPresetsList = document.getElementById('builtin-presets-list');

  const optHideOnScope = document.getElementById('opt-hide-on-scope');
  const optShowInFp = document.getElementById('opt-show-in-fp');

  const tabLayerCount = document.getElementById('tab-layer-count');
  const presetCounterBadge = document.getElementById('preset-counter-badge');
  const myPresetsCountLabel = document.getElementById('my-presets-count-label');
  const feedbackBanner = document.getElementById('feedback-banner');
  const clipboardHelper = document.getElementById('clipboard-helper');

  // Runtime State
  let isOpen = false;
  let currentLocales = {};
  let serverConfig = {
    allowedDisplayModes: { aim_only: true, armed: true, always: true, off: true },
    maxPlayerPresets: 20,
    maxCustomLayers: 6,
    defaultShareCode:
      'RT1:n=Default Cyan;d=1,c,3,00ffcc,100,1,1,000000,80;i=1,0,6,2,3,0,00ffcc,100,1,1,000000,80,0',
    builtInPresets: [],
  };

  let profileState = {
    activeCode: serverConfig.defaultShareCode,
    displayMode: 'aim_only',
    hideOnScope: true,
    showInFirstPerson: true,
    presets: [],
  };

  let reticleModel = createDefaultReticle();
  let feedbackTimer = null;

  // ==========================================================================
  // 1. Default Reticle Model & Validation Helpers
  // ==========================================================================

  function clamp(num, min, max, fallback) {
    const n = Number(num);
    if (!Number.isFinite(n)) return fallback;
    return Math.min(max, Math.max(min, n));
  }

  function sanitizeHex(hex, fallback = '#00ffcc') {
    if (typeof hex !== 'string') return fallback;
    const clean = hex.trim().replace(/^#/, '');
    if (/^[0-9a-fA-F]{6}$/.test(clean)) {
      return `#${clean.toLowerCase()}`;
    }
    return fallback;
  }

  function stripHash(hex) {
    return sanitizeHex(hex).slice(1);
  }

  function createDefaultReticle() {
    return {
      name: 'Custom Reticle',
      globalScale: 100,
      globalOpacity: 100,
      dot: {
        enabled: true,
        shape: 'c', // 'c': circle, 's': square, 'd': diamond, 'r': hollow ring
        size: 3,
        color: '#00ffcc',
        opacity: 100,
        outline: true,
        outlineWidth: 1,
        outlineColor: '#000000',
        outlineOpacity: 80,
      },
      inner: {
        enabled: true,
        tStyle: false,
        length: 6,
        thickness: 2,
        gap: 3,
        rotation: 0,
        color: '#00ffcc',
        opacity: 100,
        outline: true,
        outlineWidth: 1,
        outlineColor: '#000000',
        outlineOpacity: 80,
        roundCaps: false,
      },
      outer: {
        enabled: false,
        tStyle: false,
        length: 4,
        thickness: 2,
        gap: 12,
        rotation: 0,
        color: '#00ffcc',
        opacity: 80,
        outline: true,
        outlineWidth: 1,
        outlineColor: '#000000',
        outlineOpacity: 80,
        roundCaps: false,
      },
      circle: {
        enabled: false,
        radius: 12,
        thickness: 2,
        arc: 360,
        rotation: 0,
        color: '#00ffcc',
        opacity: 85,
        outline: true,
        outlineWidth: 1,
        outlineColor: '#000000',
        outlineOpacity: 75,
      },
      layers: [],
    };
  }

  function createDefaultCustomLayer(shape = 'chevron') {
    return {
      shape: shape, // 'cross' | 'tcross' | 'circle' | 'dot' | 'chevron' | 'line'
      enabled: true,
      size: 6,
      thickness: 2,
      gap: 4,
      angle: 75,
      rotation: 0,
      offsetX: 0,
      offsetY: 0,
      color: '#00ffcc',
      opacity: 100,
      outline: true,
      outlineWidth: 1,
      outlineColor: '#000000',
      outlineOpacity: 80,
    };
  }

  // ==========================================================================
  // 2. RT1 Compact Share Code Encoder & Decoder
  // ==========================================================================

  function encodeReticleToRT1(model) {
    const parts = [];

    const safeName = String(model.name || 'Custom')
      .replace(/[;|=,<>]/g, '')
      .trim()
      .slice(0, 28);
    if (safeName && safeName !== 'Custom Reticle') {
      parts.push(`n=${safeName}`);
    }

    const gScale = clamp(model.globalScale, 50, 200, 100);
    const gOp = clamp(model.globalOpacity, 10, 100, 100);
    if (gScale !== 100 || gOp !== 100) {
      parts.push(`g=${gScale},${gOp}`);
    }

    // Dot: enabled,shape,size,color,opacity,outline,outlineWidth,outlineColor,outlineOpacity
    const d = model.dot;
    if (d && d.enabled) {
      parts.push(
        `d=1,${d.shape || 'c'},${clamp(d.size, 1, 30, 3)},${stripHash(d.color)},${clamp(
          d.opacity,
          0,
          100,
          100
        )},${d.outline ? 1 : 0},${clamp(d.outlineWidth, 1, 6, 1)},${stripHash(
          d.outlineColor
        )},${clamp(d.outlineOpacity, 0, 100, 80)}`
      );
    } else {
      parts.push('d=0');
    }

    // Inner: enabled,tStyle,length,thickness,gap,rotation,color,opacity,outline,outlineWidth,outlineColor,outlineOpacity,roundCaps
    const encodeCrossSlot = (key, s) => {
      if (s && s.enabled) {
        parts.push(
          `${key}=1,${s.tStyle ? 1 : 0},${clamp(s.length, 1, 60, 6)},${clamp(
            s.thickness,
            1,
            20,
            2
          )},${clamp(s.gap, -20, 60, 3)},${clamp(s.rotation, 0, 360, 0)},${stripHash(
            s.color
          )},${clamp(s.opacity, 0, 100, 100)},${s.outline ? 1 : 0},${clamp(
            s.outlineWidth,
            1,
            6,
            1
          )},${stripHash(s.outlineColor)},${clamp(s.outlineOpacity, 0, 100, 80)},${
            s.roundCaps ? 1 : 0
          }`
        );
      } else if (key === 'i') {
        parts.push('i=0');
      }
    };

    encodeCrossSlot('i', model.inner);
    encodeCrossSlot('o', model.outer);

    // Circle: enabled,radius,thickness,arc,rotation,color,opacity,outline,outlineWidth,outlineColor,outlineOpacity
    const c = model.circle;
    if (c && c.enabled) {
      parts.push(
        `c=1,${clamp(c.radius, 2, 100, 12)},${clamp(c.thickness, 1, 16, 2)},${clamp(
          c.arc,
          30,
          360,
          360
        )},${clamp(c.rotation, 0, 360, 0)},${stripHash(c.color)},${clamp(
          c.opacity,
          0,
          100,
          85
        )},${c.outline ? 1 : 0},${clamp(c.outlineWidth, 1, 6, 1)},${stripHash(
          c.outlineColor
        )},${clamp(c.outlineOpacity, 0, 100, 75)}`
      );
    }

    // Custom Layers: shape,enabled,size,thickness,gap,angle,rotation,offsetX,offsetY,color,opacity,outline,outlineWidth,outlineColor,outlineOpacity
    if (Array.isArray(model.layers) && model.layers.length > 0) {
      const maxL = serverConfig.maxCustomLayers || 6;
      const layerTokens = [];
      model.layers.slice(0, maxL).forEach((ly) => {
        if (!ly) return;
        layerTokens.push(
          [
            ly.shape || 'chevron',
            ly.enabled !== false ? 1 : 0,
            clamp(ly.size, 1, 60, 6),
            clamp(ly.thickness, 1, 20, 2),
            clamp(ly.gap, -20, 60, 4),
            clamp(ly.angle, 15, 360, 75),
            clamp(ly.rotation, 0, 360, 0),
            clamp(ly.offsetX, -120, 120, 0),
            clamp(ly.offsetY, -120, 120, 0),
            stripHash(ly.color),
            clamp(ly.opacity, 0, 100, 100),
            ly.outline ? 1 : 0,
            clamp(ly.outlineWidth, 1, 6, 1),
            stripHash(ly.outlineColor),
            clamp(ly.outlineOpacity, 0, 100, 80),
          ].join(',')
        );
      });
      if (layerTokens.length > 0) {
        parts.push(`L=${layerTokens.join('|')}`);
      }
    }

    return `RT1:${parts.join(';')}`;
  }

  function decodeRT1ToReticle(codeStr) {
    if (typeof codeStr !== 'string') return { ok: false };
    const trimmed = codeStr.trim();
    if (!trimmed.startsWith('RT1:')) return { ok: false };

    const body = trimmed.slice(4);
    const model = createDefaultReticle();
    model.dot.enabled = false;
    model.inner.enabled = false;
    model.outer.enabled = false;
    model.circle.enabled = false;
    model.layers = [];

    const segments = body.split(';');
    for (const seg of segments) {
      if (!seg) continue;
      const eqIdx = seg.indexOf('=');
      if (eqIdx === -1) continue;
      const key = seg.slice(0, eqIdx).trim();
      const val = seg.slice(eqIdx + 1).trim();

      if (key === 'n') {
        model.name = val.replace(/[<>]/g, '').slice(0, 28) || 'Custom Reticle';
      } else if (key === 'g') {
        const p = val.split(',');
        model.globalScale = clamp(p[0], 50, 200, 100);
        model.globalOpacity = clamp(p[1], 10, 100, 100);
      } else if (key === 'd') {
        const p = val.split(',');
        model.dot.enabled = p[0] === '1';
        if (p.length > 1) {
          const validShapes = ['c', 's', 'd', 'r'];
          model.dot.shape = validShapes.includes(p[1]) ? p[1] : 'c';
          model.dot.size = clamp(p[2], 1, 30, 3);
          model.dot.color = sanitizeHex(p[3], '#00ffcc');
          model.dot.opacity = clamp(p[4], 0, 100, 100);
          model.dot.outline = p[5] !== '0';
          model.dot.outlineWidth = clamp(p[6], 1, 6, 1);
          model.dot.outlineColor = sanitizeHex(p[7], '#000000');
          model.dot.outlineOpacity = clamp(p[8], 0, 100, 80);
        }
      } else if (key === 'i' || key === 'o') {
        const target = key === 'i' ? model.inner : model.outer;
        const p = val.split(',');
        target.enabled = p[0] === '1';
        if (p.length > 1) {
          target.tStyle = p[1] === '1';
          target.length = clamp(p[2], 1, 60, 6);
          target.thickness = clamp(p[3], 1, 20, 2);
          target.gap = clamp(p[4], -20, 60, 3);
          target.rotation = clamp(p[5], 0, 360, 0);
          target.color = sanitizeHex(p[6], '#00ffcc');
          target.opacity = clamp(p[7], 0, 100, 100);
          target.outline = p[8] !== '0';
          target.outlineWidth = clamp(p[9], 1, 6, 1);
          target.outlineColor = sanitizeHex(p[10], '#000000');
          target.outlineOpacity = clamp(p[11], 0, 100, 80);
          target.roundCaps = p[12] === '1';
        }
      } else if (key === 'c') {
        const p = val.split(',');
        model.circle.enabled = p[0] === '1';
        if (p.length > 1) {
          model.circle.radius = clamp(p[1], 2, 100, 12);
          model.circle.thickness = clamp(p[2], 1, 16, 2);
          model.circle.arc = clamp(p[3], 30, 360, 360);
          model.circle.rotation = clamp(p[4], 0, 360, 0);
          model.circle.color = sanitizeHex(p[5], '#00ffcc');
          model.circle.opacity = clamp(p[6], 0, 100, 85);
          model.circle.outline = p[7] !== '0';
          model.circle.outlineWidth = clamp(p[8], 1, 6, 1);
          model.circle.outlineColor = sanitizeHex(p[9], '#000000');
          model.circle.outlineOpacity = clamp(p[10], 0, 100, 75);
        }
      } else if (key === 'L' && val) {
        const maxL = serverConfig.maxCustomLayers || 6;
        const validShapes = ['cross', 'tcross', 'circle', 'dot', 'chevron', 'line'];
        const rawItems = val.split('|').slice(0, maxL);
        rawItems.forEach((raw) => {
          const p = raw.split(',');
          if (p.length < 2) return;
          const ly = createDefaultCustomLayer(validShapes.includes(p[0]) ? p[0] : 'chevron');
          ly.enabled = p[1] !== '0';
          ly.size = clamp(p[2], 1, 60, 6);
          ly.thickness = clamp(p[3], 1, 20, 2);
          ly.gap = clamp(p[4], -20, 60, 4);
          ly.angle = clamp(p[5], 15, 360, 75);
          ly.rotation = clamp(p[6], 0, 360, 0);
          ly.offsetX = clamp(p[7], -120, 120, 0);
          ly.offsetY = clamp(p[8], -120, 120, 0);
          ly.color = sanitizeHex(p[9], '#00ffcc');
          ly.opacity = clamp(p[10], 0, 100, 100);
          ly.outline = p[11] !== '0';
          ly.outlineWidth = clamp(p[12], 1, 6, 1);
          ly.outlineColor = sanitizeHex(p[13], '#000000');
          ly.outlineOpacity = clamp(p[14], 0, 100, 80);
          model.layers.push(ly);
        });
      }
    }

    return { ok: true, data: model };
  }

  // ==========================================================================
  // 3. SVG Vector Rendering Engine
  // ==========================================================================

  function createSvgEl(tag, attrs = {}) {
    const el = document.createElementNS(SVG_NS, tag);
    Object.entries(attrs).forEach(([k, v]) => {
      if (v !== undefined && v !== null) {
        el.setAttribute(k, String(v));
      }
    });
    return el;
  }

  function describeArcPath(cx, cy, r, degSpan) {
    const span = clamp(degSpan, 1, 359.9, 180);
    const startAngle = -90 - span / 2;
    const endAngle = -90 + span / 2;
    const startRad = (startAngle * Math.PI) / 180;
    const endRad = (endAngle * Math.PI) / 180;
    const x1 = cx + r * Math.cos(startRad);
    const y1 = cy + r * Math.sin(startRad);
    const x2 = cx + r * Math.cos(endRad);
    const y2 = cy + r * Math.sin(endRad);
    const largeArcFlag = span > 180 ? 1 : 0;
    return `M ${x1.toFixed(2)} ${y1.toFixed(2)} A ${r.toFixed(2)} ${r.toFixed(
      2
    )} 0 ${largeArcFlag} 1 ${x2.toFixed(2)} ${y2.toFixed(2)}`;
  }

  function renderDotGroup(parentG, d, ox = 0, oy = 0, rot = 0) {
    if (!d || !d.enabled) return;
    const g = createSvgEl('g', {
      transform: `translate(${ox}, ${oy}) rotate(${rot})`,
    });

    const size = clamp(d.size, 1, 40, 3);
    const shape = d.shape || 'c';
    const mainOp = clamp(d.opacity, 0, 100, 100) / 100;
    const outOp = clamp(d.outlineOpacity, 0, 100, 80) / 100;
    const outW = d.outline ? clamp(d.outlineWidth, 1, 6, 1) : 0;

    if (shape === 'r') {
      // Hollow ring dot
      const r = Math.max(1.5, size);
      if (outW > 0) {
        g.appendChild(
          createSvgEl('circle', {
            cx: 0,
            cy: 0,
            r: r,
            fill: 'none',
            stroke: d.outlineColor,
            'stroke-width': 2 + outW * 2,
            'stroke-opacity': outOp,
          })
        );
      }
      g.appendChild(
        createSvgEl('circle', {
          cx: 0,
          cy: 0,
          r: r,
          fill: 'none',
          stroke: d.color,
          'stroke-width': 2,
          'stroke-opacity': mainOp,
        })
      );
    } else if (shape === 's' || shape === 'd') {
      const rotExtra = shape === 'd' ? 45 : 0;
      const half = size / 2;
      if (outW > 0) {
        g.appendChild(
          createSvgEl('rect', {
            x: -half,
            y: -half,
            width: size,
            height: size,
            fill: d.color,
            'fill-opacity': mainOp,
            stroke: d.outlineColor,
            'stroke-width': outW,
            'stroke-opacity': outOp,
            transform: rotExtra ? `rotate(${rotExtra})` : undefined,
          })
        );
      } else {
        g.appendChild(
          createSvgEl('rect', {
            x: -half,
            y: -half,
            width: size,
            height: size,
            fill: d.color,
            'fill-opacity': mainOp,
            transform: rotExtra ? `rotate(${rotExtra})` : undefined,
          })
        );
      }
    } else {
      // Standard circle dot
      const r = size / 2;
      if (outW > 0) {
        g.appendChild(
          createSvgEl('circle', {
            cx: 0,
            cy: 0,
            r: r,
            fill: d.color,
            'fill-opacity': mainOp,
            stroke: d.outlineColor,
            'stroke-width': outW,
            'stroke-opacity': outOp,
          })
        );
      } else {
        g.appendChild(
          createSvgEl('circle', {
            cx: 0,
            cy: 0,
            r: r,
            fill: d.color,
            'fill-opacity': mainOp,
          })
        );
      }
    }

    parentG.appendChild(g);
  }

  function renderCrossGroup(parentG, s, ox = 0, oy = 0) {
    if (!s || !s.enabled) return;
    const len = clamp(s.length ?? s.size, 1, 60, 6);
    const thick = clamp(s.thickness, 1, 20, 2);
    const gap = clamp(s.gap, -20, 60, 3);
    const rot = clamp(s.rotation, 0, 360, 0);
    const mainOp = clamp(s.opacity, 0, 100, 100) / 100;
    const outOp = clamp(s.outlineOpacity, 0, 100, 80) / 100;
    const outW = s.outline ? clamp(s.outlineWidth, 1, 6, 1) : 0;
    const rx = s.roundCaps ? thick / 2 : 0;

    const g = createSvgEl('g', {
      transform: `translate(${ox}, ${oy}) rotate(${rot})`,
    });

    const halfT = thick / 2;
    const arms = [
      // Right
      { x: gap, y: -halfT, w: len, h: thick },
      // Left
      { x: -(gap + len), y: -halfT, w: len, h: thick },
      // Bottom
      { x: -halfT, y: gap, w: thick, h: len },
    ];
    if (!s.tStyle) {
      // Top
      arms.push({ x: -halfT, y: -(gap + len), w: thick, h: len });
    }

    arms.forEach((arm) => {
      if (outW > 0) {
        g.appendChild(
          createSvgEl('rect', {
            x: arm.x - outW,
            y: arm.y - outW,
            width: arm.w + outW * 2,
            height: arm.h + outW * 2,
            rx: rx > 0 ? rx + outW / 2 : 0,
            fill: s.outlineColor,
            'fill-opacity': outOp,
          })
        );
      }
      g.appendChild(
        createSvgEl('rect', {
          x: arm.x,
          y: arm.y,
          width: arm.w,
          height: arm.h,
          rx: rx,
          fill: s.color,
          'fill-opacity': mainOp,
        })
      );
    });

    parentG.appendChild(g);
  }

  function renderCircleGroup(parentG, c, ox = 0, oy = 0) {
    if (!c || !c.enabled) return;
    const r = clamp(c.radius ?? c.size, 2, 100, 12);
    const thick = clamp(c.thickness, 1, 20, 2);
    const arc = clamp(c.arc ?? c.angle ?? 360, 15, 360, 360);
    const rot = clamp(c.rotation, 0, 360, 0);
    const mainOp = clamp(c.opacity, 0, 100, 85) / 100;
    const outOp = clamp(c.outlineOpacity, 0, 100, 75) / 100;
    const outW = c.outline ? clamp(c.outlineWidth, 1, 6, 1) : 0;

    const g = createSvgEl('g', {
      transform: `translate(${ox}, ${oy}) rotate(${rot})`,
    });

    if (arc >= 359.5) {
      if (outW > 0) {
        g.appendChild(
          createSvgEl('circle', {
            cx: 0,
            cy: 0,
            r: r,
            fill: 'none',
            stroke: c.outlineColor,
            'stroke-width': thick + outW * 2,
            'stroke-opacity': outOp,
          })
        );
      }
      g.appendChild(
        createSvgEl('circle', {
          cx: 0,
          cy: 0,
          r: r,
          fill: 'none',
          stroke: c.color,
          'stroke-width': thick,
          'stroke-opacity': mainOp,
        })
      );
    } else {
      const dPath = describeArcPath(0, 0, r, arc);
      if (outW > 0) {
        g.appendChild(
          createSvgEl('path', {
            d: dPath,
            fill: 'none',
            stroke: c.outlineColor,
            'stroke-width': thick + outW * 2,
            'stroke-opacity': outOp,
            'stroke-linecap': 'round',
          })
        );
      }
      g.appendChild(
        createSvgEl('path', {
          d: dPath,
          fill: 'none',
          stroke: c.color,
          'stroke-width': thick,
          'stroke-opacity': mainOp,
          'stroke-linecap': 'round',
        })
      );
    }

    parentG.appendChild(g);
  }

  function renderChevronGroup(parentG, ly) {
    if (!ly || !ly.enabled) return;
    const len = clamp(ly.size, 2, 60, 8);
    const thick = clamp(ly.thickness, 1, 16, 2);
    const spreadDeg = clamp(ly.angle, 20, 160, 75);
    const rot = clamp(ly.rotation, 0, 360, 0);
    const ox = clamp(ly.offsetX, -120, 120, 0);
    const oy = clamp(ly.offsetY, -120, 120, 0);
    const mainOp = clamp(ly.opacity, 0, 100, 100) / 100;
    const outOp = clamp(ly.outlineOpacity, 0, 100, 80) / 100;
    const outW = ly.outline ? clamp(ly.outlineWidth, 1, 6, 1) : 0;

    const halfRad = ((spreadDeg / 2) * Math.PI) / 180;
    const dx = Math.sin(halfRad) * len;
    const dy = Math.cos(halfRad) * len;
    const dPath = `M ${(-dx).toFixed(2)} ${dy.toFixed(2)} L 0 0 L ${dx.toFixed(2)} ${dy.toFixed(2)}`;

    const g = createSvgEl('g', {
      transform: `translate(${ox}, ${oy}) rotate(${rot})`,
    });

    if (outW > 0) {
      g.appendChild(
        createSvgEl('path', {
          d: dPath,
          fill: 'none',
          stroke: ly.outlineColor,
          'stroke-width': thick + outW * 2,
          'stroke-opacity': outOp,
          'stroke-linecap': 'round',
          'stroke-linejoin': 'miter',
        })
      );
    }
    g.appendChild(
      createSvgEl('path', {
        d: dPath,
        fill: 'none',
        stroke: ly.color,
        'stroke-width': thick,
        'stroke-opacity': mainOp,
        'stroke-linecap': 'round',
        'stroke-linejoin': 'miter',
      })
    );

    parentG.appendChild(g);
  }

  function renderSingleLineGroup(parentG, ly) {
    if (!ly || !ly.enabled) return;
    const len = clamp(ly.size, 1, 80, 8);
    const thick = clamp(ly.thickness, 1, 20, 2);
    const rot = clamp(ly.rotation, 0, 360, 0);
    const ox = clamp(ly.offsetX, -120, 120, 0);
    const oy = clamp(ly.offsetY, -120, 120, 0);
    const mainOp = clamp(ly.opacity, 0, 100, 100) / 100;
    const outOp = clamp(ly.outlineOpacity, 0, 100, 80) / 100;
    const outW = ly.outline ? clamp(ly.outlineWidth, 1, 6, 1) : 0;

    const g = createSvgEl('g', {
      transform: `translate(${ox}, ${oy}) rotate(${rot})`,
    });

    const x = -len / 2;
    const y = -thick / 2;
    if (outW > 0) {
      g.appendChild(
        createSvgEl('rect', {
          x: x - outW,
          y: y - outW,
          width: len + outW * 2,
          height: thick + outW * 2,
          fill: ly.outlineColor,
          'fill-opacity': outOp,
        })
      );
    }
    g.appendChild(
      createSvgEl('rect', {
        x: x,
        y: y,
        width: len,
        height: thick,
        fill: ly.color,
        'fill-opacity': mainOp,
      })
    );

    parentG.appendChild(g);
  }

  function renderReticleToSvg(svgEl, model) {
    if (!svgEl || !model) return;
    while (svgEl.firstChild) {
      svgEl.removeChild(svgEl.firstChild);
    }

    const scale = clamp(model.globalScale, 50, 200, 100) / 100;
    const gOp = clamp(model.globalOpacity, 10, 100, 100) / 100;

    const rootG = createSvgEl('g', {
      transform: `scale(${scale})`,
      opacity: gOp,
    });

    // 1. Circle slot (bottom layer of standard slots)
    renderCircleGroup(rootG, model.circle, 0, 0);

    // 2. Outer Lines
    renderCrossGroup(rootG, model.outer, 0, 0);

    // 3. Inner Lines
    renderCrossGroup(rootG, model.inner, 0, 0);

    // 4. Center Dot
    renderDotGroup(rootG, model.dot, 0, 0, 0);

    // 5. Custom Layers (in order)
    if (Array.isArray(model.layers)) {
      model.layers.forEach((ly) => {
        if (!ly || !ly.enabled) return;
        const shape = ly.shape || 'chevron';
        if (shape === 'cross' || shape === 'tcross') {
          renderCrossGroup(
            rootG,
            {
              ...ly,
              length: ly.size,
              tStyle: shape === 'tcross',
            },
            ly.offsetX || 0,
            ly.offsetY || 0
          );
        } else if (shape === 'circle') {
          renderCircleGroup(
            rootG,
            {
              ...ly,
              radius: ly.size,
              arc: ly.angle || 360,
            },
            ly.offsetX || 0,
            ly.offsetY || 0
          );
        } else if (shape === 'dot') {
          renderDotGroup(
            rootG,
            {
              ...ly,
              shape: 'c',
            },
            ly.offsetX || 0,
            ly.offsetY || 0,
            ly.rotation || 0
          );
        } else if (shape === 'chevron') {
          renderChevronGroup(rootG, ly);
        } else if (shape === 'line') {
          renderSingleLineGroup(rootG, ly);
        }
      });
    }

    svgEl.appendChild(rootG);
  }

  function refreshAllReticleCanvases() {
    const code = encodeReticleToRT1(reticleModel);
    profileState.activeCode = code;

    renderReticleToSvg(hudSvg, reticleModel);
    renderReticleToSvg(previewSvg, reticleModel);

    if (inputShareCode && document.activeElement !== inputShareCode) {
      inputShareCode.value = code;
    }
    if (footerLiveCode) {
      footerLiveCode.value = code;
    }
    if (inputGlobalScale) {
      inputGlobalScale.value = String(reticleModel.globalScale || 100);
    }
    if (valGlobalScale) {
      valGlobalScale.textContent = `${reticleModel.globalScale || 100}%`;
    }
    if (inputGlobalOpacity) {
      inputGlobalOpacity.value = String(reticleModel.globalOpacity || 100);
    }
    if (valGlobalOpacity) {
      valGlobalOpacity.textContent = `${reticleModel.globalOpacity || 100}%`;
    }
  }

  // ==========================================================================
  // 4. Translation & Theme Helpers
  // ==========================================================================

  function t(key, subs) {
    let str = currentLocales[key] !== undefined ? String(currentLocales[key]) : key;
    if (subs && typeof subs === 'object') {
      Object.entries(subs).forEach(([k, v]) => {
        str = str.replace(new RegExp(`%\\{${k}\\}`, 'g'), String(v));
      });
    }
    return str;
  }

  function applyTheme(theme) {
    if (!theme || typeof theme !== 'object') return;
    const rootStyle = document.documentElement.style;
    if (theme.primaryColor) rootStyle.setProperty('--primary', String(theme.primaryColor));
    if (theme.accentColor) rootStyle.setProperty('--accent', String(theme.accentColor));
    if (theme.bgOpacity) rootStyle.setProperty('--bg-opacity', String(theme.bgOpacity));
    if (theme.borderRadius) rootStyle.setProperty('--radius', String(theme.borderRadius));

    if (theme.position && appEl) {
      appEl.classList.remove('pos-left', 'pos-right', 'pos-center');
      const pos = String(theme.position).toLowerCase();
      appEl.classList.add(pos === 'left' ? 'pos-left' : 'pos-right');
    }
  }

  function applyLocales(locales) {
    if (!locales || typeof locales !== 'object') return;
    currentLocales = { ...currentLocales, ...locales };

    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      if (key && currentLocales[key] !== undefined) {
        el.textContent = String(currentLocales[key]);
      }
    });

    document.querySelectorAll('[data-i18n-placeholder]').forEach((el) => {
      const key = el.getAttribute('data-i18n-placeholder');
      if (key && currentLocales[key] !== undefined) {
        el.setAttribute('placeholder', String(currentLocales[key]));
      }
    });
  }

  function showFeedback(message, isError = false) {
    if (!feedbackBanner) return;
    if (feedbackTimer) clearTimeout(feedbackTimer);
    feedbackBanner.textContent = message;
    feedbackBanner.classList.toggle('error', Boolean(isError));
    feedbackBanner.classList.remove('hidden');
    feedbackTimer = setTimeout(() => {
      feedbackBanner.classList.add('hidden');
    }, 3200);
  }

  // ==========================================================================
  // 5. Dynamic UI Builders (Standard Slots, Custom Layers, Display Modes, Presets)
  // ==========================================================================

  function createSliderControl(labelKey, min, max, step, value, onInput) {
    const wrap = document.createElement('div');
    wrap.className = 'control-row';

    const label = document.createElement('div');
    label.className = 'control-label';
    const textSpan = document.createElement('span');
    textSpan.textContent = t(labelKey);
    const valSpan = document.createElement('span');
    valSpan.className = 'val-num';
    valSpan.textContent = String(value);
    label.appendChild(textSpan);
    label.appendChild(valSpan);

    const input = document.createElement('input');
    input.type = 'range';
    input.min = String(min);
    input.max = String(max);
    input.step = String(step);
    input.value = String(value);

    input.addEventListener('input', () => {
      const numVal = Number(input.value);
      valSpan.textContent = String(numVal);
      onInput(numVal);
      refreshAllReticleCanvases();
    });

    wrap.appendChild(label);
    wrap.appendChild(input);
    return wrap;
  }

  function createColorControl(labelKey, hexValue, onInput) {
    const wrap = document.createElement('div');
    wrap.className = 'control-row';

    const label = document.createElement('div');
    label.className = 'control-label';
    label.textContent = t(labelKey);

    const pickerRow = document.createElement('div');
    pickerRow.className = 'color-picker-wrap';

    const colorInput = document.createElement('input');
    colorInput.type = 'color';
    colorInput.value = sanitizeHex(hexValue);

    const hexBadge = document.createElement('span');
    hexBadge.className = 'hex-badge';
    hexBadge.textContent = sanitizeHex(hexValue).toUpperCase();

    colorInput.addEventListener('input', () => {
      const clean = sanitizeHex(colorInput.value);
      hexBadge.textContent = clean.toUpperCase();
      onInput(clean);
      refreshAllReticleCanvases();
    });

    pickerRow.appendChild(colorInput);
    pickerRow.appendChild(hexBadge);
    wrap.appendChild(label);
    wrap.appendChild(pickerRow);
    return wrap;
  }

  function createSelectControl(labelKey, options, currentVal, onChange) {
    const wrap = document.createElement('div');
    wrap.className = 'control-row';

    const label = document.createElement('div');
    label.className = 'control-label';
    label.textContent = t(labelKey);

    const select = document.createElement('select');
    select.className = 'select-input';
    options.forEach((opt) => {
      const o = document.createElement('option');
      o.value = opt.value;
      o.textContent = opt.label;
      if (opt.value === currentVal) o.selected = true;
      select.appendChild(o);
    });

    select.addEventListener('change', () => {
      onChange(select.value);
      refreshAllReticleCanvases();
    });

    wrap.appendChild(label);
    wrap.appendChild(select);
    return wrap;
  }

  function createCheckboxPill(labelKey, checked, onChange) {
    const lbl = document.createElement('label');
    lbl.className = 'check-pill';
    const chk = document.createElement('input');
    chk.type = 'checkbox';
    chk.checked = Boolean(checked);
    chk.addEventListener('change', () => {
      onChange(chk.checked);
      refreshAllReticleCanvases();
    });
    const span = document.createElement('span');
    span.textContent = t(labelKey);
    lbl.appendChild(chk);
    lbl.appendChild(span);
    return lbl;
  }

  function buildOutlineControls(slotObj) {
    const box = document.createElement('div');
    box.className = 'outline-subbox';

    const checks = document.createElement('div');
    checks.className = 'inline-checks';
    checks.appendChild(
      createCheckboxPill('param_outline', slotObj.outline, (v) => {
        slotObj.outline = v;
      })
    );
    box.appendChild(checks);

    const grid = document.createElement('div');
    grid.className = 'control-grid-2';
    grid.appendChild(
      createColorControl('param_outline_color', slotObj.outlineColor, (v) => {
        slotObj.outlineColor = v;
      })
    );
    grid.appendChild(
      createSliderControl('param_outline_width', 1, 6, 1, slotObj.outlineWidth, (v) => {
        slotObj.outlineWidth = v;
      })
    );
    grid.appendChild(
      createSliderControl('param_outline_opacity', 0, 100, 5, slotObj.outlineOpacity, (v) => {
        slotObj.outlineOpacity = v;
      })
    );
    box.appendChild(grid);

    return box;
  }

  function renderStandardSlotsUI() {
    if (!standardSlotsContainer) return;
    standardSlotsContainer.innerHTML = '';

    // 1. Center Dot
    standardSlotsContainer.appendChild(
      buildStandardSlotCard('slot_dot', reticleModel.dot, (body, d) => {
        const g1 = document.createElement('div');
        g1.className = 'control-grid-2';
        g1.appendChild(
          createSelectControl(
            'param_shape',
            [
              { value: 'c', label: t('shape_circle') },
              { value: 's', label: t('shape_square') },
              { value: 'd', label: t('shape_diamond') },
              { value: 'r', label: t('shape_ring') },
            ],
            d.shape,
            (v) => {
              d.shape = v;
            }
          )
        );
        g1.appendChild(
          createSliderControl('param_size', 1, 24, 1, d.size, (v) => {
            d.size = v;
          })
        );
        g1.appendChild(
          createColorControl('param_color', d.color, (v) => {
            d.color = v;
          })
        );
        g1.appendChild(
          createSliderControl('param_opacity', 5, 100, 5, d.opacity, (v) => {
            d.opacity = v;
          })
        );
        body.appendChild(g1);
        body.appendChild(buildOutlineControls(d));
      })
    );

    // 2. Inner Lines & 3. Outer Lines
    const buildCrossBody = (body, s) => {
      const checks = document.createElement('div');
      checks.className = 'inline-checks';
      checks.appendChild(
        createCheckboxPill('param_t_style', s.tStyle, (v) => {
          s.tStyle = v;
        })
      );
      checks.appendChild(
        createCheckboxPill('param_round_caps', s.roundCaps, (v) => {
          s.roundCaps = v;
        })
      );
      body.appendChild(checks);

      const g1 = document.createElement('div');
      g1.className = 'control-grid-2';
      g1.appendChild(
        createSliderControl('param_length', 1, 50, 1, s.length, (v) => {
          s.length = v;
        })
      );
      g1.appendChild(
        createSliderControl('param_thickness', 1, 16, 1, s.thickness, (v) => {
          s.thickness = v;
        })
      );
      g1.appendChild(
        createSliderControl('param_gap', -15, 50, 1, s.gap, (v) => {
          s.gap = v;
        })
      );
      g1.appendChild(
        createSliderControl('param_rotation', 0, 360, 5, s.rotation, (v) => {
          s.rotation = v;
        })
      );
      g1.appendChild(
        createColorControl('param_color', s.color, (v) => {
          s.color = v;
        })
      );
      g1.appendChild(
        createSliderControl('param_opacity', 5, 100, 5, s.opacity, (v) => {
          s.opacity = v;
        })
      );
      body.appendChild(g1);
      body.appendChild(buildOutlineControls(s));
    };

    standardSlotsContainer.appendChild(
      buildStandardSlotCard('slot_inner', reticleModel.inner, buildCrossBody)
    );
    standardSlotsContainer.appendChild(
      buildStandardSlotCard('slot_outer', reticleModel.outer, buildCrossBody)
    );

    // 4. Circle / Ring
    standardSlotsContainer.appendChild(
      buildStandardSlotCard('slot_circle', reticleModel.circle, (body, c) => {
        const g1 = document.createElement('div');
        g1.className = 'control-grid-2';
        g1.appendChild(
          createSliderControl('param_radius', 2, 80, 1, c.radius, (v) => {
            c.radius = v;
          })
        );
        g1.appendChild(
          createSliderControl('param_thickness', 1, 16, 1, c.thickness, (v) => {
            c.thickness = v;
          })
        );
        g1.appendChild(
          createSliderControl('param_arc', 30, 360, 15, c.arc, (v) => {
            c.arc = v;
          })
        );
        g1.appendChild(
          createSliderControl('param_rotation', 0, 360, 5, c.rotation, (v) => {
            c.rotation = v;
          })
        );
        g1.appendChild(
          createColorControl('param_color', c.color, (v) => {
            c.color = v;
          })
        );
        g1.appendChild(
          createSliderControl('param_opacity', 5, 100, 5, c.opacity, (v) => {
            c.opacity = v;
          })
        );
        body.appendChild(g1);
        body.appendChild(buildOutlineControls(c));
      })
    );
  }

  function buildStandardSlotCard(titleKey, slotObj, populateBodyFn) {
    const card = document.createElement('div');
    card.className = `slot-card ${slotObj.enabled ? '' : 'disabled-slot'}`;

    const header = document.createElement('div');
    header.className = 'slot-header';

    const titleGroup = document.createElement('div');
    titleGroup.className = 'slot-title-group';
    const dot = document.createElement('span');
    dot.className = 'slot-color-dot';
    dot.style.background = slotObj.color;
    const title = document.createElement('span');
    title.className = 'slot-title';
    title.textContent = t(titleKey);
    titleGroup.appendChild(dot);
    titleGroup.appendChild(title);

    const rightControls = document.createElement('div');
    rightControls.className = 'slot-controls-right';
    const enablePill = createCheckboxPill('param_enabled', slotObj.enabled, (checked) => {
      slotObj.enabled = checked;
      card.classList.toggle('disabled-slot', !checked);
    });
    rightControls.appendChild(enablePill);

    header.appendChild(titleGroup);
    header.appendChild(rightControls);
    card.appendChild(header);

    const body = document.createElement('div');
    body.className = 'slot-body';
    populateBodyFn(body, slotObj);
    card.appendChild(body);

    return card;
  }

  function renderCustomLayersUI() {
    if (!customLayersContainer) return;
    customLayersContainer.innerHTML = '';

    const layers = reticleModel.layers || [];
    const maxL = serverConfig.maxCustomLayers || 6;

    if (tabLayerCount) {
      tabLayerCount.textContent = `${layers.length}/${maxL}`;
    }
    if (btnAddLayer) {
      btnAddLayer.disabled = layers.length >= maxL;
    }

    if (layers.length === 0) {
      const hint = document.createElement('div');
      hint.className = 'empty-hint';
      hint.textContent = t('layer_empty_hint');
      customLayersContainer.appendChild(hint);
      return;
    }

    layers.forEach((ly, idx) => {
      const card = document.createElement('div');
      card.className = `slot-card ${ly.enabled ? '' : 'disabled-slot'}`;

      const header = document.createElement('div');
      header.className = 'slot-header';

      const titleGroup = document.createElement('div');
      titleGroup.className = 'slot-title-group';
      const dot = document.createElement('span');
      dot.className = 'slot-color-dot';
      dot.style.background = ly.color;
      const title = document.createElement('span');
      title.className = 'slot-title';
      title.textContent = t('layer_item_title', { index: idx + 1 });
      titleGroup.appendChild(dot);
      titleGroup.appendChild(title);

      const rightControls = document.createElement('div');
      rightControls.className = 'slot-controls-right';

      rightControls.appendChild(
        createCheckboxPill('param_enabled', ly.enabled, (checked) => {
          ly.enabled = checked;
          card.classList.toggle('disabled-slot', !checked);
        })
      );

      if (layers.length < maxL) {
        const btnClone = document.createElement('button');
        btnClone.type = 'button';
        btnClone.className = 'btn btn-ghost btn-sm';
        btnClone.textContent = t('btn_duplicate_layer');
        btnClone.addEventListener('click', () => {
          reticleModel.layers.push({ ...ly });
          renderCustomLayersUI();
          refreshAllReticleCanvases();
        });
        rightControls.appendChild(btnClone);
      }

      const btnDel = document.createElement('button');
      btnDel.type = 'button';
      btnDel.className = 'btn btn-danger btn-sm';
      btnDel.textContent = t('btn_delete_layer');
      btnDel.addEventListener('click', () => {
        reticleModel.layers.splice(idx, 1);
        renderCustomLayersUI();
        refreshAllReticleCanvases();
      });
      rightControls.appendChild(btnDel);

      header.appendChild(titleGroup);
      header.appendChild(rightControls);
      card.appendChild(header);

      const body = document.createElement('div');
      body.className = 'slot-body';

      const g1 = document.createElement('div');
      g1.className = 'control-grid-2';

      g1.appendChild(
        createSelectControl(
          'param_shape',
          [
            { value: 'chevron', label: t('shape_chevron') },
            { value: 'line', label: t('shape_line') },
            { value: 'cross', label: t('shape_cross') },
            { value: 'tcross', label: t('shape_tcross') },
            { value: 'circle', label: t('shape_circle') },
            { value: 'dot', label: t('shape_ring') },
          ],
          ly.shape,
          (v) => {
            ly.shape = v;
            renderCustomLayersUI();
          }
        )
      );

      g1.appendChild(
        createSliderControl('param_size', 1, 60, 1, ly.size, (v) => {
          ly.size = v;
        })
      );

      if (ly.shape !== 'dot') {
        g1.appendChild(
          createSliderControl('param_thickness', 1, 16, 1, ly.thickness, (v) => {
            ly.thickness = v;
          })
        );
      }

      if (ly.shape === 'cross' || ly.shape === 'tcross') {
        g1.appendChild(
          createSliderControl('param_gap', -15, 50, 1, ly.gap, (v) => {
            ly.gap = v;
          })
        );
      }

      if (ly.shape === 'chevron' || ly.shape === 'circle') {
        g1.appendChild(
          createSliderControl(
            ly.shape === 'chevron' ? 'param_angle' : 'param_arc',
            20,
            360,
            5,
            ly.angle,
            (v) => {
              ly.angle = v;
            }
          )
        );
      }

      g1.appendChild(
        createSliderControl('param_rotation', 0, 360, 5, ly.rotation, (v) => {
          ly.rotation = v;
        })
      );
      g1.appendChild(
        createSliderControl('param_offset_x', -100, 100, 1, ly.offsetX, (v) => {
          ly.offsetX = v;
        })
      );
      g1.appendChild(
        createSliderControl('param_offset_y', -100, 100, 1, ly.offsetY, (v) => {
          ly.offsetY = v;
        })
      );
      g1.appendChild(
        createColorControl('param_color', ly.color, (v) => {
          ly.color = v;
          dot.style.background = v;
        })
      );
      g1.appendChild(
        createSliderControl('param_opacity', 5, 100, 5, ly.opacity, (v) => {
          ly.opacity = v;
        })
      );

      body.appendChild(g1);
      body.appendChild(buildOutlineControls(ly));
      card.appendChild(body);
      customLayersContainer.appendChild(card);
    });
  }

  function renderDisplayModesUI() {
    if (!displayModesList) return;
    displayModesList.innerHTML = '';

    const allowed = serverConfig.allowedDisplayModes || {
      aim_only: true,
      armed: true,
      always: true,
      off: true,
    };

    const modes = [
      { id: 'aim_only', titleKey: 'mode_aim_only', descKey: 'mode_aim_only_desc' },
      { id: 'armed', titleKey: 'mode_armed', descKey: 'mode_armed_desc' },
      { id: 'always', titleKey: 'mode_always', descKey: 'mode_always_desc' },
      { id: 'off', titleKey: 'mode_off', descKey: 'mode_off_desc' },
    ];

    modes.forEach((m) => {
      const isAllowed = Boolean(allowed[m.id]);
      const isActive = profileState.displayMode === m.id;

      const card = document.createElement('div');
      card.className = `mode-card ${isActive ? 'active' : ''} ${isAllowed ? '' : 'locked'}`;

      const info = document.createElement('div');
      info.className = 'mode-info';
      const h3 = document.createElement('h3');
      h3.textContent = t(m.titleKey);
      const p = document.createElement('p');
      p.textContent = t(m.descKey);
      info.appendChild(h3);
      info.appendChild(p);
      card.appendChild(info);

      if (!isAllowed) {
        const lockSpan = document.createElement('span');
        lockSpan.className = 'lock-tag';
        lockSpan.textContent = t('mode_locked_badge');
        card.appendChild(lockSpan);
      } else {
        card.addEventListener('click', () => {
          profileState.displayMode = m.id;
          renderDisplayModesUI();
          saveToLua(false);
        });
      }

      displayModesList.appendChild(card);
    });

    if (optHideOnScope) {
      optHideOnScope.checked = profileState.hideOnScope !== false;
    }
    if (optShowInFp) {
      optShowInFp.checked = profileState.showInFirstPerson !== false;
    }
  }

  function createMiniPresetRow(preset, isBuiltIn) {
    const row = document.createElement('div');
    row.className = 'preset-item';

    const left = document.createElement('div');
    left.className = 'preset-left';

    const thumb = document.createElement('div');
    thumb.className = 'preset-thumb';
    const miniSvg = createSvgEl('svg', {
      width: 34,
      height: 34,
      viewBox: '-30 -30 60 60',
    });
    const decoded = decodeRT1ToReticle(preset.code);
    if (decoded.ok) {
      renderReticleToSvg(miniSvg, decoded.data);
    }
    thumb.appendChild(miniSvg);

    const nameEl = document.createElement('span');
    nameEl.className = 'preset-name';
    nameEl.textContent = preset.name || 'Preset';

    left.appendChild(thumb);
    left.appendChild(nameEl);

    const actions = document.createElement('div');
    actions.className = 'preset-actions';

    const btnLoad = document.createElement('button');
    btnLoad.type = 'button';
    btnLoad.className = 'btn btn-primary btn-sm';
    btnLoad.textContent = t('btn_load');
    btnLoad.addEventListener('click', () => {
      loadReticleFromShareCode(preset.code, true);
    });

    const btnCopy = document.createElement('button');
    btnCopy.type = 'button';
    btnCopy.className = 'btn btn-secondary btn-sm';
    btnCopy.textContent = t('btn_copy');
    btnCopy.addEventListener('click', () => {
      copyTextToClipboard(preset.code);
    });

    actions.appendChild(btnLoad);
    actions.appendChild(btnCopy);

    if (!isBuiltIn) {
      const btnDel = document.createElement('button');
      btnDel.type = 'button';
      btnDel.className = 'btn btn-danger btn-sm';
      btnDel.textContent = t('btn_delete');
      btnDel.addEventListener('click', () => {
        profileState.presets = (profileState.presets || []).filter((p) => p.id !== preset.id);
        renderPresetsUI();
        saveToLua(true, t('msg_preset_deleted'), 'info');
        showFeedback(t('msg_preset_deleted'), false);
      });
      actions.appendChild(btnDel);
    }

    row.appendChild(left);
    row.appendChild(actions);
    return row;
  }

  function renderPresetsUI() {
    const myPresets = Array.isArray(profileState.presets) ? profileState.presets : [];
    const maxP = serverConfig.maxPlayerPresets || 20;

    if (presetCounterBadge) {
      presetCounterBadge.textContent = `${myPresets.length} / ${maxP}`;
    }
    if (myPresetsCountLabel) {
      myPresetsCountLabel.textContent = `${myPresets.length} / ${maxP}`;
    }

    if (myPresetsList) {
      myPresetsList.innerHTML = '';
      if (myPresets.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty-hint';
        empty.textContent = t('preset_empty_hint');
        myPresetsList.appendChild(empty);
      } else {
        myPresets.forEach((p) => {
          myPresetsList.appendChild(createMiniPresetRow(p, false));
        });
      }
    }

    if (builtinPresetsList) {
      builtinPresetsList.innerHTML = '';
      const builtIns = Array.isArray(serverConfig.builtInPresets)
        ? serverConfig.builtInPresets
        : [];
      builtIns.forEach((p) => {
        builtinPresetsList.appendChild(createMiniPresetRow(p, true));
      });
    }
  }

  function rebuildAllEditorControls() {
    renderStandardSlotsUI();
    renderCustomLayersUI();
    renderDisplayModesUI();
    renderPresetsUI();
    refreshAllReticleCanvases();
  }

  // ==========================================================================
  // 6. Share Code Copy / Import & Lua Communication
  // ==========================================================================

  function getResourceName() {
    if (typeof window.GetParentResourceName === 'function') {
      return window.GetParentResourceName();
    }
    return 'wu-reticle';
  }

  async function postNUI(endpoint, payload = {}) {
    const url = `https://${getResourceName()}/${endpoint}`;
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
      });
      return await response.json();
    } catch (err) {
      return { ok: false, offline: true };
    }
  }

  function saveToLua(syncServer = true, notifyMessage = null, notifyType = 'success') {
    profileState.activeCode = encodeReticleToRT1(reticleModel);
    postNUI('saveProfile', {
      activeCode: profileState.activeCode,
      displayMode: profileState.displayMode,
      hideOnScope: profileState.hideOnScope,
      showInFirstPerson: profileState.showInFirstPerson,
      presets: profileState.presets,
      syncServer: syncServer,
      notify: Boolean(notifyMessage),
      notifyMessage: notifyMessage,
      notifyType: notifyType,
    });
  }

  function copyTextToClipboard(text) {
    const clean = String(text || '').trim();
    if (!clean) return;

    const finishCopy = () => {
      showFeedback(t('msg_code_copied'), false);
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard
        .writeText(clean)
        .then(finishCopy)
        .catch(() => {
          fallbackCopy(clean);
          finishCopy();
        });
    } else {
      fallbackCopy(clean);
      finishCopy();
    }
  }

  function fallbackCopy(text) {
    if (!clipboardHelper) return;
    clipboardHelper.value = text;
    clipboardHelper.focus();
    clipboardHelper.select();
    try {
      document.execCommand('copy');
    } catch (_) {
      // ignore
    }
  }

  function loadReticleFromShareCode(codeStr, showToast = true) {
    const res = decodeRT1ToReticle(codeStr);
    if (!res.ok || !res.data) {
      showFeedback(t('msg_invalid_code'), true);
      return false;
    }

    reticleModel = res.data;
    rebuildAllEditorControls();
    saveToLua(true);

    if (showToast) {
      showFeedback(t('msg_code_imported'), false);
    }
    return true;
  }

  // ==========================================================================
  // 7. Editor Lifecycle & Event Listeners
  // ==========================================================================

  function syncStateFromPayload(payload) {
    if (payload.theme) applyTheme(payload.theme);
    if (payload.locales) applyLocales(payload.locales);
    if (payload.config && typeof payload.config === 'object') {
      serverConfig = { ...serverConfig, ...payload.config };
    }
    if (payload.profile && typeof payload.profile === 'object') {
      profileState = { ...profileState, ...payload.profile };
      const parsed = decodeRT1ToReticle(profileState.activeCode);
      if (parsed.ok && parsed.data) {
        reticleModel = parsed.data;
      }
    }
    rebuildAllEditorControls();
  }

  function openEditor(payload = {}) {
    syncStateFromPayload(payload);
    isOpen = true;
    appEl.classList.remove('hidden');
    hudContainer.classList.remove('hud-hidden');
    if (centerGuide) centerGuide.classList.remove('hidden');
  }

  async function closeEditor(notifyLua = true) {
    if (!isOpen && appEl.classList.contains('hidden')) return;
    isOpen = false;
    appEl.classList.add('hidden');
    if (centerGuide) centerGuide.classList.add('hidden');

    profileState.activeCode = encodeReticleToRT1(reticleModel);
    if (notifyLua) {
      await postNUI('close', { profile: profileState });
    }
  }

  // Global Scale & Opacity Listeners
  if (inputGlobalScale) {
    inputGlobalScale.addEventListener('input', () => {
      reticleModel.globalScale = clamp(inputGlobalScale.value, 50, 200, 100);
      refreshAllReticleCanvases();
    });
  }
  if (inputGlobalOpacity) {
    inputGlobalOpacity.addEventListener('input', () => {
      reticleModel.globalOpacity = clamp(inputGlobalOpacity.value, 10, 100, 100);
      refreshAllReticleCanvases();
    });
  }

  // Preview Background Switcher
  document.querySelectorAll('.bg-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.bg-btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      const bg = btn.getAttribute('data-bg') || 'night';
      if (previewStage) {
        previewStage.className = `preview-stage bg-${bg}`;
      }
    });
  });

  // Tab Navigation
  document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetTab = btn.getAttribute('data-tab');
      document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach((p) => p.classList.remove('active'));
      btn.classList.add('active');
      const pane = document.getElementById(`tab-pane-${targetTab}`);
      if (pane) pane.classList.add('active');
    });
  });

  // Add Custom Layer
  if (btnAddLayer) {
    btnAddLayer.addEventListener('click', () => {
      const maxL = serverConfig.maxCustomLayers || 6;
      if (!Array.isArray(reticleModel.layers)) reticleModel.layers = [];
      if (reticleModel.layers.length >= maxL) return;
      reticleModel.layers.push(createDefaultCustomLayer('chevron'));
      renderCustomLayersUI();
      refreshAllReticleCanvases();
    });
  }

  // Display Options Toggles
  if (optHideOnScope) {
    optHideOnScope.addEventListener('change', () => {
      profileState.hideOnScope = optHideOnScope.checked;
      saveToLua(false);
    });
  }
  if (optShowInFp) {
    optShowInFp.addEventListener('change', () => {
      profileState.showInFirstPerson = optShowInFp.checked;
      saveToLua(false);
    });
  }

  // Share Code Copy & Import
  if (btnCopyCode) {
    btnCopyCode.addEventListener('click', () => {
      const code = encodeReticleToRT1(reticleModel);
      copyTextToClipboard(code);
    });
  }
  if (footerLiveCode) {
    footerLiveCode.addEventListener('click', () => {
      copyTextToClipboard(footerLiveCode.value);
    });
  }
  if (btnImportCode) {
    btnImportCode.addEventListener('click', () => {
      if (!inputShareCode) return;
      loadReticleFromShareCode(inputShareCode.value, true);
    });
  }

  // Save New Personal Preset
  if (btnSavePreset) {
    btnSavePreset.addEventListener('click', () => {
      const maxP = serverConfig.maxPlayerPresets || 20;
      if (!Array.isArray(profileState.presets)) profileState.presets = [];
      if (profileState.presets.length >= maxP) {
        showFeedback(t('msg_preset_limit', { max: maxP }), true);
        return;
      }

      const rawName = inputPresetName ? inputPresetName.value.trim() : '';
      const name = rawName || `Preset #${profileState.presets.length + 1}`;
      reticleModel.name = name;
      const code = encodeReticleToRT1(reticleModel);

      profileState.presets.unshift({
        id: `p_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        name: name,
        code: code,
        updatedAt: Math.floor(Date.now() / 1000),
      });

      if (inputPresetName) inputPresetName.value = '';
      renderPresetsUI();
      refreshAllReticleCanvases();
      saveToLua(true, t('msg_preset_saved', { name }), 'success');
      showFeedback(t('msg_preset_saved', { name }), false);
    });
  }

  // Reset to Default
  if (btnReset) {
    btnReset.addEventListener('click', () => {
      const defaultCode =
        serverConfig.defaultShareCode ||
        'RT1:n=Default Cyan;d=1,c,3,00ffcc,100,1,1,000000,80;i=1,0,6,2,3,0,00ffcc,100,1,1,000000,80,0';
      loadReticleFromShareCode(defaultCode, false);
      showFeedback(t('msg_reset_done'), false);
    });
  }

  // Close & Apply Buttons
  if (btnClose) {
    btnClose.addEventListener('click', () => closeEditor(true));
  }
  if (btnApplyClose) {
    btnApplyClose.addEventListener('click', () => closeEditor(true));
  }

  // Escape Key Listener
  window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && isOpen) {
      event.preventDefault();
      closeEditor(true);
    }
  });

  // FiveM SendNUIMessage Listener
  window.addEventListener('message', (event) => {
    const payload = event.data;
    if (!payload || typeof payload !== 'object') return;

    const action = String(payload.action || '').toUpperCase();
    switch (action) {
      case 'SYNC_PROFILE':
        syncStateFromPayload(payload);
        break;
      case 'OPEN_EDITOR':
        openEditor(payload);
        break;
      case 'CLOSE_EDITOR':
        closeEditor(false);
        break;
      case 'SET_HUD_VISIBLE':
        if (hudContainer) {
          hudContainer.classList.toggle('hud-hidden', !payload.visible && !isOpen);
        }
        break;
      default:
        break;
    }
  });

  // Initial Boot
  rebuildAllEditorControls();
  postNUI('ready', {});
})();
