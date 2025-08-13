// =======================================
// 📄 FILE: html/js/spray-editor.js
// 🔌 STEP: STEP 1 — NUI SPRAY EDITOR
// Fixed SetNuiFocus errors and NUI callback issues
// VERSION: 1.0.0
// =======================================

// Global Variables
let fabricCanvas = null;
let currentGang = null;
let currentColors = [];
let isInitialized = false;

// SprayEditor Klasse
class SprayEditor {
    constructor() {
        this.canvas = null;
        this.isInitialized = false;
        this.tools = {
            brush: null,
            eraser: null,
            text: null,
            shapes: null
        };
        this.history = [];
        this.historyIndex = -1;
        
        this.init();
    }
    
    async init() {
        try {
            // Warte bis Fabric.js verfügbar ist
            if (typeof fabric === 'undefined') {
                // Fabric.js über CDN laden
                await this.loadFabricJS();
            }
            
            await this.initializeCanvas();
            this.setupTools();
            this.setupEventListeners();
            this.isInitialized = true;
            
            console.log('[SprayEditor] Initialized successfully');
        } catch (error) {
            console.error('[SprayEditor] Initialization failed:', error);
            this.showError('Editor konnte nicht initialisiert werden', error);
        }
    }
    
    async loadFabricJS() {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = 'https://cdnjs.cloudflare.com/ajax/libs/fabric.js/5.3.0/fabric.min.js';
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }
    
    async initializeCanvas() {
        const canvasElement = document.getElementById('spray-canvas');
        if (!canvasElement) {
            throw new Error('Canvas element not found');
        }
        
        this.canvas = new fabric.Canvas('spray-canvas', {
            width: 800,
            height: 600,
            backgroundColor: 'transparent'
        });
        
        // Canvas Events
        this.canvas.on('path:created', () => this.saveState());
        this.canvas.on('object:added', () => this.saveState());
        this.canvas.on('object:removed', () => this.saveState());
        
        // Anfangszustand speichern
        this.saveState();
    }
    
    setupTools() {
        // Brush Tool
        this.setupBrushTool();
        
        // Eraser Tool
        this.setupEraserTool();
        
        // Text Tool
        this.setupTextTool();
        
        // Shape Tools
        this.setupShapeTools();
    }
    
    setupBrushTool() {
        this.canvas.isDrawingMode = true;
        this.canvas.freeDrawingBrush.width = 10;
        this.canvas.freeDrawingBrush.color = '#FF0000';
        
        // Brush Settings Event Listeners
        const brushSize = document.getElementById('brush-size');
        if (brushSize) {
            brushSize.addEventListener('input', (e) => {
                this.canvas.freeDrawingBrush.width = parseInt(e.target.value);
            });
        }
        
        const brushColor = document.getElementById('brush-color');
        if (brushColor) {
            brushColor.addEventListener('change', (e) => {
                this.canvas.freeDrawingBrush.color = e.target.value;
            });
        }
    }
    
    setupEraserTool() {
        // Eraser durch spezielle Brush implementieren
        const eraserBtn = document.getElementById('eraser-tool');
        if (eraserBtn) {
            eraserBtn.addEventListener('click', () => {
                this.canvas.isDrawingMode = true;
                this.canvas.freeDrawingBrush.color = 'transparent';
                this.canvas.freeDrawingBrush.globalCompositeOperation = 'destination-out';
            });
        }
    }
    
    setupTextTool() {
        const textBtn = document.getElementById('text-tool');
        if (textBtn) {
            textBtn.addEventListener('click', () => {
                this.addText();
            });
        }
    }
    
    setupShapeTools() {
        const rectangleBtn = document.getElementById('rectangle-tool');
        if (rectangleBtn) {
            rectangleBtn.addEventListener('click', () => {
                this.addRectangle();
            });
        }
        
        const circleBtn = document.getElementById('circle-tool');
        if (circleBtn) {
            circleBtn.addEventListener('click', () => {
                this.addCircle();
            });
        }
    }
    
    setupEventListeners() {
        // Save Button
        const saveBtn = document.getElementById('save-spray');
        if (saveBtn) {
            saveBtn.addEventListener('click', () => {
                this.saveSpray();
            });
        }
        
        // Clear Button
        const clearBtn = document.getElementById('clear-canvas');
        if (clearBtn) {
            clearBtn.addEventListener('click', () => {
                this.clearCanvas();
            });
        }
        
        // Undo/Redo
        const undoBtn = document.getElementById('undo-btn');
        if (undoBtn) {
            undoBtn.addEventListener('click', () => {
                this.undo();
            });
        }
        
        const redoBtn = document.getElementById('redo-btn');
        if (redoBtn) {
            redoBtn.addEventListener('click', () => {
                this.redo();
            });
        }
        
        // Close Button - FIX: Proper NUI close
        const closeBtn = document.getElementById('close-editor');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                this.closeEditor();
            });
        }
        
        // ESC Key Handler
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeEditor();
            }
        });
    }
    
    setGangColors(gang, colors) {
        this.currentGang = gang;
        this.currentColors = colors;
        
        // Update Color Palette
        this.updateColorPalette(colors);
    }
    
    updateColorPalette(colors) {
        const palette = document.getElementById('color-palette');
        if (!palette) return;
        
        palette.innerHTML = '';
        
        colors.forEach(color => {
            const colorBtn = document.createElement('button');
            colorBtn.className = 'color-btn';
            colorBtn.style.backgroundColor = color;
            colorBtn.title = color;
            
            colorBtn.addEventListener('click', () => {
                this.setActiveColor(color);
            });
            
            palette.appendChild(colorBtn);
        });
    }
    
    setActiveColor(color) {
        this.canvas.freeDrawingBrush.color = color;
        
        // Update UI
        const brushColor = document.getElementById('brush-color');
        if (brushColor) {
            brushColor.value = color;
        }
    }
    
    addText() {
        const text = new fabric.Text('Gang Text', {
            left: 100,
            top: 100,
            fontSize: 20,
            fill: this.canvas.freeDrawingBrush.color
        });
        
        this.canvas.add(text);
        this.canvas.setActiveObject(text);
    }
    
    addRectangle() {
        const rect = new fabric.Rect({
            left: 100,
            top: 100,
            width: 100,
            height: 100,
            fill: 'transparent',
            stroke: this.canvas.freeDrawingBrush.color,
            strokeWidth: 3
        });
        
        this.canvas.add(rect);
        this.canvas.setActiveObject(rect);
    }
    
    addCircle() {
        const circle = new fabric.Circle({
            left: 100,
            top: 100,
            radius: 50,
            fill: 'transparent',
            stroke: this.canvas.freeDrawingBrush.color,
            strokeWidth: 3
        });
        
        this.canvas.add(circle);
        this.canvas.setActiveObject(circle);
    }
    
    saveState() {
        const state = JSON.stringify(this.canvas.toJSON());
        
        // Remove future states if we're not at the end
        if (this.historyIndex < this.history.length - 1) {
            this.history = this.history.slice(0, this.historyIndex + 1);
        }
        
        this.history.push(state);
        this.historyIndex++;
        
        // Limit history size
        if (this.history.length > 50) {
            this.history.shift();
            this.historyIndex--;
        }
    }
    
    undo() {
        if (this.historyIndex > 0) {
            this.historyIndex--;
            const state = this.history[this.historyIndex];
            this.canvas.loadFromJSON(state, () => {
                this.canvas.renderAll();
            });
        }
    }
    
    redo() {
        if (this.historyIndex < this.history.length - 1) {
            this.historyIndex++;
            const state = this.history[this.historyIndex];
            this.canvas.loadFromJSON(state, () => {
                this.canvas.renderAll();
            });
        }
    }
    
    clearCanvas() {
        this.canvas.clear();
        this.canvas.backgroundColor = 'transparent';
        this.saveState();
    }
    
    async saveSpray() {
        try {
            if (!this.canvas) {
                throw new Error('Canvas not initialized');
            }
            
            // Show loading
            this.showLoading(true);
            
            // Get canvas data as base64
            const dataURL = this.canvas.toDataURL({
                format: 'png',
                quality: 0.8,
                multiplier: 1
            });
            
            // Prepare data for Lua
            const sprayData = {
                textureData: dataURL,
                metadata: {
                    gang: this.currentGang,
                    colors: this.currentColors,
                    canvasData: this.canvas.toJSON(),
                    timestamp: Date.now(),
                    resolution: {
                        width: this.canvas.width,
                        height: this.canvas.height
                    }
                }
            };
            
            // Send to Lua - FIX: Proper fetch call
            const response = await this.sendToLua('saveSprayDesign', sprayData);
            
            if (response && response.success) {
                this.showNotification('Spray gespeichert!', 'success');
                this.closeEditor();
            } else {
                throw new Error(response?.error || 'Fehler beim Speichern');
            }
            
        } catch (error) {
            console.error('[SprayEditor] Save error:', error);
            this.showError('Fehler beim Speichern des Sprays', error);
        } finally {
            this.showLoading(false);
        }
    }
    
    // FIX: Proper NUI close implementation
    closeEditor() {
        try {
            // Send close event to Lua
            this.sendToLua('closeEditor', {});
            
            // Hide UI
            const editorElement = document.getElementById('spray-editor');
            if (editorElement) {
                editorElement.classList.add('hidden');
            }
            
            console.log('[SprayEditor] Editor closed');
        } catch (error) {
            console.error('[SprayEditor] Close error:', error);
        }
    }
    
    // FIX: Proper fetch implementation for NUI callbacks
    async sendToLua(action, data) {
        try {
            const resourceName = GetParentResourceName ? GetParentResourceName() : 'spray-system';
            
            const response = await fetch(`https://${resourceName}/${action}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(data || {})
            });
            
            return await response.json();
        } catch (error) {
            console.error('[SprayEditor] Lua communication error:', error);
            return { success: false, error: error.message };
        }
    }
    
    showLoading(show) {
        const overlay = document.getElementById('loading-overlay');
        if (overlay) {
            if (show) {
                overlay.classList.remove('hidden');
            } else {
                overlay.classList.add('hidden');
            }
        }
    }
    
    showNotification(message, type = 'info') {
        const notification = document.getElementById('notification');
        const text = document.getElementById('notification-text');
        
        if (notification && text) {
            text.textContent = message;
            notification.className = `notification ${type}`;
            notification.classList.remove('hidden');
            
            setTimeout(() => {
                notification.classList.add('hidden');
            }, 3000);
        }
    }
    
    showError(message, error = null) {
        const modal = document.getElementById('error-modal');
        const messageEl = document.getElementById('error-message');
        const stackEl = document.getElementById('error-stack');
        
        if (messageEl) messageEl.textContent = message;
        if (stackEl && error) {
            stackEl.textContent = error.stack || error.toString();
        }
        
        if (modal) modal.classList.remove('hidden');
        
        console.error('[SprayEditor] Error:', message, error);
    }
}

// Global Functions for HTML Events
function closeSprayEditor() {
    if (window.sprayEditor) {
        window.sprayEditor.closeEditor();
    }
}

function saveCurrentSpray() {
    if (window.sprayEditor) {
        window.sprayEditor.saveSpray();
    }
}

function clearCanvas() {
    if (window.sprayEditor) {
        window.sprayEditor.clearCanvas();
    }
}

function undoLastAction() {
    if (window.sprayEditor) {
        window.sprayEditor.undo();
    }
}

function redoLastAction() {
    if (window.sprayEditor) {
        window.sprayEditor.redo();
    }
}

// Global Functions für Modal Controls
function closeTemplateSelector() {
    const modal = document.getElementById('template-selector');
    if (modal) modal.classList.add('hidden');
}

function closeUrlInput() {
    const modal = document.getElementById('url-input-modal');
    if (modal) modal.classList.add('hidden');
}

function closeErrorModal() {
    const modal = document.getElementById('error-modal');
    if (modal) modal.classList.add('hidden');
}

function toggleErrorDetails() {
    const details = document.getElementById('error-details');
    if (details) details.classList.toggle('hidden');
}

function openCustomEditor() {
    closeTemplateSelector();
    if (window.sprayEditor) {
        document.getElementById('spray-editor').classList.remove('hidden');
    }
}

function openUrlInput() {
    closeTemplateSelector();
    const modal = document.getElementById('url-input-modal');
    if (modal) modal.classList.remove('hidden');
}

// NUI Message Handler für FiveM - FIX: Proper SetNuiFocus handling
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'openSprayEditor':
            document.getElementById('spray-editor').classList.remove('hidden');
            
            if (!window.sprayEditor) {
                window.sprayEditor = new SprayEditor();
            }
            
            // Gang-Farben setzen wenn verfügbar
            if (data.gangColors && data.gang) {
                window.sprayEditor.setGangColors(data.gang, data.gangColors);
            }
            
            break;
            
        case 'closeSprayEditor':
            closeSprayEditor();
            break;
            
        case 'updateGangColors':
            if (window.sprayEditor && data.colors) {
                window.sprayEditor.updateColorPalette(data.colors);
            }
            break;
    }
});

// Global Helper Functions
function GetParentResourceName() {
    try {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'spray-system';
    } catch {
        return 'spray-system';
    }
}

console.log('[SprayEditor] Script loaded successfully');