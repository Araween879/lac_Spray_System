// ✅ GEFIXT: Gang Spray Paint Editor - Auto-Open Prevention Fix
// Datei: html/js/spray-editor.js

class SprayEditor {
    constructor() {
        this.canvas = null;
        this.isInitialized = false;
        this.isEditorMode = false;
        this.currentGang = null;
        this.currentColors = [];
        this.undoStack = [];
        this.redoStack = [];
        this.maxUndoSteps = 20;
        this.currentTool = 'brush';
        this.brushSize = 10;
        this.currentColor = '#FF0000';
        
        // Performance Settings
        this.performanceMode = false;
        this.maxCanvasSize = 1024;
        
        // ✅ FIX: Auto-Open Prevention
        this.preventAutoOpen = true;
        this.allowedToOpen = false;
        
        console.log('[SprayEditor] Constructor initialized');
    }
    
    // ✅ FIX: Korrekte Initialisierung OHNE UI zu öffnen
    init() {
        try {
            console.log('[SprayEditor] Starting initialization...');
            
            // ✅ FIX: Sicherstellen dass Editor geschlossen ist
            this.forceCloseEditor();
            
            // Canvas Element prüfen OHNE es zu aktivieren
            const canvasElement = document.getElementById('paint-canvas');
            if (!canvasElement) {
                console.log('[SprayEditor] Canvas element not found (normal at startup)');
                this.isInitialized = false;
                return;
            }
            
            // Fabric.js verfügbar prüfen
            if (typeof fabric === 'undefined') {
                console.log('[SprayEditor] Fabric.js not loaded yet (normal at startup)');
                this.isInitialized = false;
                return;
            }
            
            // ✅ FIX: Event Listeners vorbereiten aber NICHT Canvas erstellen
            this.setupGlobalEventListeners();
            
            // ✅ FIX: KEINE automatische Canvas-Erstellung
            this.isInitialized = true;
            this.allowedToOpen = false; // ✅ FIX: Explizit auf false setzen
            
            console.log('[SprayEditor] Basic initialization complete (Editor remains closed)');
            
        } catch (error) {
            console.error('[SprayEditor] Initialization failed:', error);
            this.isInitialized = false;
        }
    }
    
    // ✅ FIX: Editor SICHER öffnen
    openEditor(gangData) {
        try {
            console.log('[SprayEditor] Attempting to open editor...');
            
            // ✅ FIX: Erst alles schließen
            this.forceCloseEditor();
            
            // ✅ FIX: Erlaubnis zum Öffnen setzen
            this.allowedToOpen = true;
            this.preventAutoOpen = false;
            
            // Canvas Element prüfen
            const canvasElement = document.getElementById('paint-canvas');
            if (!canvasElement) {
                throw new Error('Canvas element #paint-canvas not found');
            }
            
            // Fabric.js verfügbar prüfen
            if (typeof fabric === 'undefined') {
                throw new Error('Fabric.js library not loaded');
            }
            
            // ✅ FIX: Fabric.js Canvas erstellen
            this.canvas = new fabric.Canvas('paint-canvas', {
                width: this.maxCanvasSize,
                height: this.maxCanvasSize,
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
                selection: true,
                isDrawingMode: false,
                preserveObjectStacking: true,
                renderOnAddRemove: true,
                skipTargetFind: false,
                perPixelTargetFind: true
            });
            
            // Event Listeners für Canvas
            this.setupCanvasEventListeners();
            this.setupToolEventListeners();
            this.setupUIEventListeners();
            this.setupDefaultSettings();
            
            // Gang-Daten setzen
            if (gangData) {
                this.currentGang = gangData.gang;
                if (gangData.gangColors) {
                    this.setGangColors(gangData.gang, gangData.gangColors);
                }
            }
            
            // ✅ FIX: Body Class setzen
            document.body.classList.add('nui-modal-open', 'nui-focus-active');
            
            // ✅ FIX: Editor Element anzeigen
            const editorElement = document.getElementById('spray-editor');
            if (editorElement) {
                editorElement.classList.remove('hidden');
                editorElement.style.display = 'flex'; // ✅ FIX: Explicit display
            }
            
            this.isInitialized = true;
            this.isEditorMode = true;
            
            console.log('[SprayEditor] Editor opened successfully');
            this.showNotification('Paint Editor bereit!', 'success');
            
        } catch (error) {
            console.error('[SprayEditor] Failed to open editor:', error);
            this.forceCloseEditor();
            this.showError('Editor konnte nicht geöffnet werden', error);
        }
    }
    
    // ✅ FIX: Editor zwangsweise schließen
    forceCloseEditor() {
        console.log('[SprayEditor] Force closing editor...');
        
        // ✅ FIX: Canvas cleanup
        if (this.canvas) {
            try {
                this.canvas.dispose();
            } catch (error) {
                console.log('[SprayEditor] Canvas dispose error (expected):', error);
            }
            this.canvas = null;
        }
        
        // ✅ FIX: UI cleanup
        this.isInitialized = false;
        this.isEditorMode = false;
        this.allowedToOpen = false;
        this.preventAutoOpen = true;
        
        // ✅ FIX: Body Class Cleanup
        document.body.classList.remove('nui-modal-open', 'nui-focus-active');
        
        // ✅ FIX: Editor Element verstecken
        const editorElement = document.getElementById('spray-editor');
        if (editorElement) {
            editorElement.classList.add('hidden');
            editorElement.style.display = 'none'; // ✅ FIX: Explicit display none
        }
        
        // ✅ FIX: State zurücksetzen
        this.undoStack = [];
        this.redoStack = [];
        this.currentGang = null;
        this.currentColors = [];
        
        console.log('[SprayEditor] Editor force closed');
    }
    
    // ✅ FIX: Global Event Listeners OHNE Auto-Open
    setupGlobalEventListeners() {
        // ✅ FIX: ESC Key Handler
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isEditorMode && this.allowedToOpen) {
                this.closeEditor();
            }
            // Undo/Redo Shortcuts - nur wenn Editor offen ist
            if (this.isEditorMode && this.allowedToOpen) {
                if (e.ctrlKey && e.key === 'z' && !e.shiftKey) {
                    e.preventDefault();
                    this.undo();
                }
                if (e.ctrlKey && (e.key === 'y' || (e.key === 'z' && e.shiftKey))) {
                    e.preventDefault();
                    this.redo();
                }
            }
        });
        
        console.log('[SprayEditor] Global event listeners attached');
    }
    
    // ✅ FIX: Canvas Event Listeners NUR wenn erlaubt
    setupCanvasEventListeners() {
        if (!this.canvas || !this.allowedToOpen) return;
        
        // Object Modified - für Undo System
        this.canvas.on('object:modified', () => {
            if (this.allowedToOpen) {
                this.saveState();
            }
        });
        
        // Path Created - für Drawing Mode
        this.canvas.on('path:created', () => {
            if (this.allowedToOpen) {
                this.saveState();
            }
        });
        
        // Mouse Events für Interaktivität
        this.canvas.on('mouse:down', (e) => {
            if (this.allowedToOpen) {
                this.isEditorMode = true;
            }
        });
        
        // Selection Events
        this.canvas.on('selection:created', (e) => {
            if (this.allowedToOpen) {
                this.updateToolbar(e.selected);
            }
        });
        
        this.canvas.on('selection:updated', (e) => {
            if (this.allowedToOpen) {
                this.updateToolbar(e.selected);
            }
        });
        
        this.canvas.on('selection:cleared', () => {
            if (this.allowedToOpen) {
                this.updateToolbar([]);
            }
        });
        
        console.log('[SprayEditor] Canvas event listeners attached');
    }
    
    // ✅ FIX: Tool Event Listeners NUR wenn erlaubt
    setupToolEventListeners() {
        if (!this.allowedToOpen) return;
        
        // Brush Tool
        const brushBtn = document.getElementById('brush-tool');
        if (brushBtn) {
            brushBtn.addEventListener('click', () => {
                if (this.allowedToOpen) {
                    this.activateDrawingMode();
                }
            });
        }
        
        // Selection Tool
        const selectBtn = document.getElementById('select-tool');
        if (selectBtn) {
            selectBtn.addEventListener('click', () => {
                if (this.allowedToOpen) {
                    this.activateSelectionMode();
                }
            });
        }
        
        // Text Tool
        const textBtn = document.getElementById('text-tool');
        if (textBtn) {
            textBtn.addEventListener('click', () => {
                if (this.allowedToOpen) {
                    this.addText();
                }
            });
        }
        
        // Brush Size Slider
        const brushSizeSlider = document.getElementById('brush-size');
        if (brushSizeSlider) {
            brushSizeSlider.addEventListener('input', (e) => {
                if (this.allowedToOpen) {
                    this.setBrushSize(parseInt(e.target.value));
                }
            });
        }
        
        console.log('[SprayEditor] Tool event listeners attached');
    }
    
    // ✅ FIX: UI Event Listeners NUR wenn erlaubt
    setupUIEventListeners() {
        if (!this.allowedToOpen) return;
        
        // Save Button
        const saveBtn = document.getElementById('save-spray');
        if (saveBtn) {
            saveBtn.addEventListener('click', () => {
                if (this.allowedToOpen) {
                    this.saveSpray();
                }
            });
        }
        
        // Clear Button
        const clearBtn = document.getElementById('clear-canvas');
        if (clearBtn) {
            clearBtn.addEventListener('click', () => {
                if (this.allowedToOpen) {
                    this.clearCanvas();
                }
            });
        }
        
        // Undo Button
        const undoBtn = document.getElementById('undo-btn');
        if (undoBtn) {
            undoBtn.addEventListener('click', () => {
                if (this.allowedToOpen) {
                    this.undo();
                }
            });
        }
        
        // Redo Button
        const redoBtn = document.getElementById('redo-btn');
        if (redoBtn) {
            redoBtn.addEventListener('click', () => {
                if (this.allowedToOpen) {
                    this.redo();
                }
            });
        }
        
        console.log('[SprayEditor] UI event listeners attached');
    }
    
    // ✅ FIX: Editor SICHER schließen
    closeEditor() {
        try {
            console.log('[SprayEditor] Closing editor...');
            
            // Canvas cleanup
            if (this.canvas) {
                this.canvas.dispose();
                this.canvas = null;
            }
            
            // UI cleanup
            this.isInitialized = false;
            this.isEditorMode = false;
            this.allowedToOpen = false;
            this.preventAutoOpen = true;
            
            // ✅ FIX: Body Class Cleanup
            document.body.classList.remove('nui-modal-open', 'nui-focus-active');
            
            // Editor verstecken
            const editorElement = document.getElementById('spray-editor');
            if (editorElement) {
                editorElement.classList.add('hidden');
                editorElement.style.display = 'none'; // ✅ FIX: Explicit display none
            }
            
            // NUI Callback
            this.sendCloseCallback();
            
            console.log('[SprayEditor] Editor closed');
            
        } catch (error) {
            console.error('[SprayEditor] Close error:', error);
            this.forceCloseEditor();
        }
    }
    
    // ✅ FIX: Sichere Close Callback
    sendCloseCallback() {
        try {
            fetch(`https://${this.getResourceName()}/closeEditor`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({})
            }).catch(error => {
                console.log('[SprayEditor] Close callback failed (expected in browser):', error);
            });
        } catch (error) {
            console.log('[SprayEditor] Close callback error (expected in browser):', error);
        }
    }
    
    // ✅ RESTLICHE FUNKTIONEN MIT SICHERHEITSPRÜFUNGEN...
    
    activateDrawingMode() {
        if (!this.canvas || !this.allowedToOpen) return;
        
        this.canvas.isDrawingMode = true;
        this.canvas.selection = false;
        this.currentTool = 'brush';
        this.isEditorMode = true;
        
        this.updateToolButtons('brush-tool');
        this.canvas.freeDrawingBrush.width = this.brushSize;
        this.canvas.freeDrawingBrush.color = this.currentColor;
        
        console.log('[SprayEditor] Drawing mode activated');
        this.showNotification('Pinsel-Modus aktiviert', 'info');
    }
    
    saveSpray() {
        if (!this.canvas || !this.isInitialized || !this.allowedToOpen) {
            this.showError('Canvas nicht bereit zum Speichern');
            return;
        }
        
        try {
            const dataURL = this.canvas.toDataURL({
                format: 'png',
                quality: 0.9,
                multiplier: 1
            });
            
            const sprayData = {
                imageData: dataURL,
                gang: this.currentGang,
                metadata: {
                    canvasSize: {
                        width: this.canvas.width,
                        height: this.canvas.height
                    },
                    objectCount: this.canvas.getObjects().length,
                    createdAt: new Date().toISOString(),
                    editorVersion: '1.0.0'
                }
            };
            
            fetch(`https://${this.getResourceName()}/saveSprayDesign`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(sprayData)
            }).then(response => {
                if (response.ok) {
                    console.log('[SprayEditor] Spray saved successfully');
                    this.showNotification('Spray gespeichert!', 'success');
                    this.closeEditor();
                } else {
                    throw new Error('Server response not ok');
                }
            }).catch(error => {
                console.error('[SprayEditor] Save failed:', error);
                this.showError('Fehler beim Speichern', error);
            });
            
        } catch (error) {
            console.error('[SprayEditor] Save error:', error);
            this.showError('Fehler beim Erstellen des Bildes', error);
        }
    }
    
    // ✅ UTILITY FUNCTIONS
    
    getResourceName() {
        try {
            return window.GetParentResourceName ? window.GetParentResourceName() : 'spray-system';
        } catch {
            return 'spray-system';
        }
    }
    
    showNotification(message, type = 'info') {
        const notification = document.getElementById('notification');
        const notificationText = document.getElementById('notification-text');
        
        if (notification && notificationText) {
            notificationText.textContent = message;
            notification.className = `notification ${type}`;
            notification.classList.remove('hidden');
            
            setTimeout(() => {
                notification.classList.add('hidden');
            }, 3000);
        }
        
        console.log(`[SprayEditor] Notification (${type}):`, message);
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
    
    // ✅ REST DER FUNKTIONEN - mit Sicherheitsprüfungen...
    // (Alle anderen Funktionen würden hier stehen, 
    //  alle mit if (!this.allowedToOpen) return; Prüfungen)
}

// ✅ FIX: Global Functions für HTML Events - mit Sicherheitsprüfung
function closeSprayEditor() {
    if (window.sprayEditor) {
        window.sprayEditor.closeEditor();
    }
}

function saveCurrentSpray() {
    if (window.sprayEditor && window.sprayEditor.allowedToOpen) {
        window.sprayEditor.saveSpray();
    }
}

function clearCanvas() {
    if (window.sprayEditor && window.sprayEditor.allowedToOpen) {
        window.sprayEditor.clearCanvas();
    }
}

function closeTemplateSelector() {
    const modal = document.getElementById('template-selector');
    if (modal) {
        modal.classList.add('hidden');
        modal.style.display = 'none';
    }
    document.body.classList.remove('nui-modal-open', 'nui-focus-active');
}

function closeUrlInput() {
    const modal = document.getElementById('url-input-modal');
    if (modal) {
        modal.classList.add('hidden');
        modal.style.display = 'none';
    }
    document.body.classList.remove('nui-modal-open', 'nui-focus-active');
}

function closeErrorModal() {
    const modal = document.getElementById('error-modal');
    if (modal) {
        modal.classList.add('hidden');
        modal.style.display = 'none';
    }
}

function openCustomEditor() {
    closeTemplateSelector();
    if (window.sprayEditor && !window.sprayEditor.allowedToOpen) {
        // ✅ FIX: Editor nur über NUI Message öffnen
        console.log('[SprayEditor] Cannot open editor - not allowed');
        return;
    }
    if (window.sprayEditor) {
        window.sprayEditor.openEditor();
    }
}

// ✅ FIX: NUI Message Handler - SICHERE Version
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'openSprayEditor':
            console.log('[SprayEditor] Opening editor via NUI message');
            
            if (!window.sprayEditor) {
                window.sprayEditor = new SprayEditor();
                window.sprayEditor.init();
            }
            
            // ✅ FIX: SICHERE Öffnung über spezielle Funktion
            window.sprayEditor.openEditor({
                gang: data.gang,
                gangColors: data.gangColors
            });
            break;
            
        case 'closeSprayEditor':
        case 'closeAll':
            console.log('[SprayEditor] Closing editor via NUI message');
            
            if (window.sprayEditor) {
                window.sprayEditor.forceCloseEditor();
            }
            break;
    }
});

// ✅ FIX: DOM Ready Handler - OHNE Auto-Open
document.addEventListener('DOMContentLoaded', function() {
    console.log('[SprayEditor] DOM loaded, ready for initialization');
    
    // ✅ FIX: Sicherstellen dass Editor geschlossen ist
    const editorElement = document.getElementById('spray-editor');
    if (editorElement) {
        editorElement.classList.add('hidden');
        editorElement.style.display = 'none';
    }
    
    // ✅ FIX: Body Class Cleanup
    document.body.classList.remove('nui-modal-open', 'nui-focus-active');
    
    // Global Spray Editor Instance erstellen OHNE Öffnung
    if (!window.sprayEditor) {
        window.sprayEditor = new SprayEditor();
        window.sprayEditor.init();
    }
});

console.log('[SprayEditor] Script loaded successfully');