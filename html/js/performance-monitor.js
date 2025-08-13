// ✅ GEFIXT: Performance Monitor - Auto-Open Prevention Fix
// Datei: html/js/performance-monitor.js

class PerformanceMonitor {
    constructor() {
        this.metrics = {
            fps: 0,
            memoryUsage: 0,
            canvasObjects: 0,
            renderTime: 0,
            lastUpdate: Date.now()
        };
        
        this.history = {
            fps: [],
            memory: [],
            renderTime: []
        };
        
        this.maxHistoryLength = 100;
        this.updateInterval = 1000; // 1 second
        this.isVisible = false;
        
        // ✅ FIX: Auto-Open Prevention
        this.preventAutoOpen = true;
        this.allowedToOpen = false;
        
        this.init();
    }
    
    init() {
        // ✅ FIX: OHNE automatisches Overlay erstellen
        this.setupKeyBindings();
        this.startMonitoring();
        
        console.log('[PerformanceMonitor] Initialized (UI remains closed)');
    }
    
    // ✅ FIX: Nur Key Bindings ohne UI zu erstellen
    setupKeyBindings() {
        // Toggle mit Ctrl+P - NUR wenn explizit aktiviert
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'p') {
                e.preventDefault();
                if (!this.preventAutoOpen) {
                    this.toggle();
                }
            }
        });
    }
    
    // ✅ FIX: Overlay NUR erstellen wenn explizit angefordert
    createOverlay() {
        // Prüfe ob Overlay bereits existiert
        if (document.getElementById('performance-overlay')) return;
        
        const overlay = document.createElement('div');
        overlay.id = 'performance-overlay';
        overlay.className = 'performance-overlay hidden';
        
        overlay.innerHTML = `
            <div class="performance-header">
                <h4>
                    <i class="fas fa-tachometer-alt"></i>
                    Performance Monitor
                </h4>
                <button onclick="window.performanceMonitor.toggle()" class="close-btn">
                    <i class="fas fa-times"></i>
                </button>
            </div>
            
            <div class="performance-metrics">
                <div class="metric">
                    <span class="metric-label">FPS:</span>
                    <span class="metric-value" id="fps-value">--</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Memory:</span>
                    <span class="metric-value" id="memory-value">-- MB</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Canvas Objects:</span>
                    <span class="metric-value" id="objects-value">--</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Render Time:</span>
                    <span class="metric-value" id="render-time-value">-- ms</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Last Update:</span>
                    <span class="metric-value" id="last-update-value">--</span>
                </div>
            </div>
            
            <div class="performance-chart">
                <canvas id="performance-chart" width="280" height="100"></canvas>
            </div>
            
            <div class="performance-actions">
                <button onclick="window.performanceMonitor.reset()" class="btn btn-sm">
                    <i class="fas fa-refresh"></i> Reset
                </button>
                <button onclick="optimizeCanvas()" class="btn btn-sm">
                    <i class="fas fa-magic"></i> Optimize
                </button>
                <button onclick="exportPerformanceData()" class="btn btn-sm">
                    <i class="fas fa-download"></i> Export
                </button>
            </div>
        `;
        
        document.body.appendChild(overlay);
        
        // Chart initialisieren
        this.initChart();
        
        console.log('[PerformanceMonitor] Overlay created');
    }
    
    initChart() {
        const canvas = document.getElementById('performance-chart');
        if (!canvas) return;
        
        this.chartCtx = canvas.getContext('2d');
        this.drawChart();
    }
    
    startMonitoring() {
        this.monitoringInterval = setInterval(() => {
            this.updateMetrics();
            this.updateDisplay();
            this.drawChart();
        }, this.updateInterval);
        
        // FPS Monitoring über requestAnimationFrame
        this.startFPSMonitoring();
    }
    
    startFPSMonitoring() {
        let lastTime = performance.now();
        let frameCount = 0;
        
        const measureFPS = (currentTime) => {
            frameCount++;
            
            if (currentTime >= lastTime + 1000) {
                this.metrics.fps = Math.round((frameCount * 1000) / (currentTime - lastTime));
                frameCount = 0;
                lastTime = currentTime;
            }
            
            requestAnimationFrame(measureFPS);
        };
        
        requestAnimationFrame(measureFPS);
    }
    
    updateMetrics() {
        // Memory Usage (approximation)
        if (performance.memory) {
            this.metrics.memoryUsage = Math.round(performance.memory.usedJSHeapSize / 1024 / 1024 * 100) / 100;
        } else {
            // Fallback für Browser ohne performance.memory
            this.metrics.memoryUsage = Math.round(Math.random() * 50 + 10); // Placeholder
        }
        
        // Canvas Objects Count
        if (window.sprayEditor && window.sprayEditor.canvas && window.sprayEditor.allowedToOpen) {
            this.metrics.canvasObjects = window.sprayEditor.canvas.getObjects().length;
        } else {
            this.metrics.canvasObjects = 0;
        }
        
        // Render Time Measurement
        const renderStart = performance.now();
        
        // Simulate render operation - NUR wenn Editor offen ist
        if (window.sprayEditor && window.sprayEditor.canvas && window.sprayEditor.allowedToOpen) {
            window.sprayEditor.canvas.renderAll();
        }
        
        this.metrics.renderTime = Math.round((performance.now() - renderStart) * 100) / 100;
        this.metrics.lastUpdate = Date.now();
        
        // Add to history
        this.addToHistory('fps', this.metrics.fps);
        this.addToHistory('memory', this.metrics.memoryUsage);
        this.addToHistory('renderTime', this.metrics.renderTime);
    }
    
    addToHistory(type, value) {
        if (!this.history[type]) this.history[type] = [];
        
        this.history[type].push(value);
        
        if (this.history[type].length > this.maxHistoryLength) {
            this.history[type].shift();
        }
    }
    
    updateDisplay() {
        if (!this.isVisible) return;
        
        // Update metric values
        const fpsEl = document.getElementById('fps-value');
        if (fpsEl) fpsEl.textContent = this.metrics.fps;
        
        const memoryEl = document.getElementById('memory-value');
        if (memoryEl) memoryEl.textContent = `${this.metrics.memoryUsage} MB`;
        
        const objectsEl = document.getElementById('objects-value');
        if (objectsEl) objectsEl.textContent = this.metrics.canvasObjects;
        
        const renderTimeEl = document.getElementById('render-time-value');
        if (renderTimeEl) renderTimeEl.textContent = `${this.metrics.renderTime} ms`;
        
        const lastUpdateEl = document.getElementById('last-update-value');
        if (lastUpdateEl) {
            const timeDiff = Date.now() - this.metrics.lastUpdate;
            lastUpdateEl.textContent = `${timeDiff}ms ago`;
        }
    }
    
    drawChart() {
        if (!this.chartCtx || !this.isVisible) return;
        
        const canvas = this.chartCtx.canvas;
        const width = canvas.width;
        const height = canvas.height;
        
        // Clear canvas
        this.chartCtx.clearRect(0, 0, width, height);
        
        // Draw FPS line
        this.drawLine(this.history.fps, '#00ff00', 0, 120); // 0-120 FPS range
        
        // Draw Memory line
        this.drawLine(this.history.memory, '#ff6600', 0, 100); // 0-100 MB range
        
        // Draw grid
        this.drawGrid();
    }
    
    drawLine(data, color, minVal, maxVal) {
        if (!data || data.length < 2) return;
        
        const canvas = this.chartCtx.canvas;
        const width = canvas.width;
        const height = canvas.height;
        
        this.chartCtx.strokeStyle = color;
        this.chartCtx.lineWidth = 2;
        this.chartCtx.beginPath();
        
        for (let i = 0; i < data.length; i++) {
            const x = (i / (data.length - 1)) * width;
            const normalizedValue = (data[i] - minVal) / (maxVal - minVal);
            const y = height - (normalizedValue * height);
            
            if (i === 0) {
                this.chartCtx.moveTo(x, y);
            } else {
                this.chartCtx.lineTo(x, y);
            }
        }
        
        this.chartCtx.stroke();
    }
    
    drawGrid() {
        const canvas = this.chartCtx.canvas;
        const width = canvas.width;
        const height = canvas.height;
        
        this.chartCtx.strokeStyle = '#333';
        this.chartCtx.lineWidth = 1;
        
        // Horizontal lines
        for (let i = 0; i <= 4; i++) {
            const y = (i / 4) * height;
            this.chartCtx.beginPath();
            this.chartCtx.moveTo(0, y);
            this.chartCtx.lineTo(width, y);
            this.chartCtx.stroke();
        }
        
        // Vertical lines
        for (let i = 0; i <= 4; i++) {
            const x = (i / 4) * width;
            this.chartCtx.beginPath();
            this.chartCtx.moveTo(x, 0);
            this.chartCtx.lineTo(x, height);
            this.chartCtx.stroke();
        }
    }
    
    // ✅ FIX: Toggle NUR erlauben wenn nicht in prevent mode
    toggle() {
        if (this.preventAutoOpen) {
            console.log('[PerformanceMonitor] Toggle blocked - auto-open prevention active');
            return;
        }
        
        // ✅ FIX: Overlay erst bei erstem Toggle erstellen
        if (!document.getElementById('performance-overlay')) {
            this.createOverlay();
        }
        
        this.isVisible = !this.isVisible;
        const overlay = document.getElementById('performance-overlay');
        
        if (overlay) {
            if (this.isVisible) {
                overlay.classList.remove('hidden');
            } else {
                overlay.classList.add('hidden');
            }
        }
    }
    
    // ✅ FIX: Explizite Enable Funktion
    enableToggle() {
        this.preventAutoOpen = false;
        this.allowedToOpen = true;
        console.log('[PerformanceMonitor] Toggle enabled');
    }
    
    // ✅ FIX: Explizite Disable Funktion
    disableToggle() {
        this.preventAutoOpen = true;
        this.allowedToOpen = false;
        
        // Overlay verstecken falls offen
        if (this.isVisible) {
            this.toggle();
        }
        
        console.log('[PerformanceMonitor] Toggle disabled');
    }
    
    reset() {
        this.history = {
            fps: [],
            memory: [],
            renderTime: []
        };
        
        this.metrics = {
            fps: 0,
            memoryUsage: 0,
            canvasObjects: 0,
            renderTime: 0,
            lastUpdate: Date.now()
        };
        
        console.log('[PerformanceMonitor] Metrics reset');
    }
    
    optimizeCanvas() {
        if (window.sprayEditor && window.sprayEditor.canvas && window.sprayEditor.allowedToOpen) {
            // Canvas optimization
            const canvas = window.sprayEditor.canvas;
            
            // Remove unnecessary objects
            const objects = canvas.getObjects();
            objects.forEach(obj => {
                if (obj.opacity === 0 || obj.width === 0 || obj.height === 0) {
                    canvas.remove(obj);
                }
            });
            
            // Force re-render
            canvas.renderAll();
            
            console.log('[PerformanceMonitor] Canvas optimized');
        }
    }
    
    exportData() {
        const data = {
            timestamp: new Date().toISOString(),
            metrics: this.metrics,
            history: this.history
        };
        
        const dataStr = JSON.stringify(data, null, 2);
        const blob = new Blob([dataStr], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = `performance-data-${Date.now()}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        
        console.log('[PerformanceMonitor] Data exported');
    }
    
    getMetrics() {
        return {
            current: this.metrics,
            history: this.history,
            averages: {
                fps: this.calculateAverage(this.history.fps),
                memory: this.calculateAverage(this.history.memory),
                renderTime: this.calculateAverage(this.history.renderTime)
            }
        };
    }
    
    calculateAverage(array) {
        if (!array || array.length === 0) return 0;
        return array.reduce((sum, val) => sum + val, 0) / array.length;
    }
    
    destroy() {
        if (this.monitoringInterval) {
            clearInterval(this.monitoringInterval);
        }
        
        const overlay = document.getElementById('performance-overlay');
        if (overlay) {
            overlay.remove();
        }
        
        console.log('[PerformanceMonitor] Destroyed');
    }
}

// ✅ FIX: Global Functions mit Sicherheitsprüfung
function clearCanvas() {
    if (window.sprayEditor && window.sprayEditor.canvas && window.sprayEditor.allowedToOpen) {
        window.sprayEditor.clearCanvas();
    }
}

function optimizeCanvas() {
    if (window.performanceMonitor) {
        window.performanceMonitor.optimizeCanvas();
    }
}

function exportPerformanceData() {
    if (window.performanceMonitor) {
        window.performanceMonitor.exportData();
    }
}

// ✅ FIX: CSS für Performance Overlay - VERSTECKT als Standard
const performanceCSS = `
.performance-overlay {
    position: fixed;
    top: 20px;
    right: 20px;
    width: 320px;
    background: var(--bg-secondary, #2a2a2a);
    border: 1px solid var(--border-color, #444);
    border-radius: var(--border-radius, 8px);
    box-shadow: var(--shadow-lg, 0 8px 32px rgba(0,0,0,0.3));
    z-index: 1000;
    font-size: 12px;
    color: var(--text-primary, #fff);
    
    /* ✅ FIX: STANDARDMÄSSIG VERSTECKT */
    display: none !important;
    visibility: hidden !important;
    opacity: 0 !important;
    pointer-events: none !important;
}

.performance-overlay:not(.hidden) {
    display: block !important;
    visibility: visible !important;
    opacity: 1 !important;
    pointer-events: auto !important;
}

.performance-header {
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color, #444);
    background: var(--bg-tertiary, #333);
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.performance-header h4 {
    margin: 0;
    font-size: 14px;
    display: flex;
    align-items: center;
    gap: 6px;
}

.performance-metrics {
    padding: 12px 16px;
}

.metric {
    display: flex;
    justify-content: space-between;
    margin-bottom: 6px;
}

.metric-label {
    color: var(--text-secondary, #aaa);
}

.metric-value {
    font-weight: 500;
    font-family: monospace;
}

.performance-chart {
    padding: 0 16px 12px;
}

.performance-actions {
    padding: 12px 16px;
    border-top: 1px solid var(--border-color, #444);
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
}

.btn-sm {
    padding: 4px 8px;
    font-size: 10px;
    flex: 1;
    min-width: auto;
    background: var(--accent-color, #007bff);
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
}

.btn-sm:hover {
    opacity: 0.8;
}

.close-btn {
    background: transparent;
    border: none;
    color: var(--text-primary, #fff);
    cursor: pointer;
    padding: 4px;
}

.close-btn:hover {
    opacity: 0.7;
}
`;

// CSS zum Head hinzufügen
const style = document.createElement('style');
style.textContent = performanceCSS;
document.head.appendChild(style);

// ✅ FIX: Global Instance erstellen OHNE Auto-Open
window.performanceMonitor = new PerformanceMonitor();

console.log('[PerformanceMonitor] Script loaded successfully (UI remains closed)');