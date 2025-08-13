// ✅ GEFIXT: Template Manager - Auto-Open Prevention Fix - VOLLSTÄNDIG
// Datei: html/js/template-manager.js

class TemplateManager {
    constructor() {
        this.templates = [];
        this.filteredTemplates = [];
        this.selectedTemplate = null;
        this.currentGang = null;
        this.currentGrade = 0;
        this.currentCategory = 'all';
        this.isInitialized = false;
        
        // URL Handler State
        this.isLoadingUrl = false;
        this.urlPreviewCache = new Map();
        this.maxCacheSize = 50;
        
        // Performance Settings
        this.lazyLoadThreshold = 20;
        this.imageLoadTimeout = 10000; // 10 Sekunden
        
        // ✅ FIX: Auto-Open Prevention
        this.preventAutoOpen = true;
        this.allowedToOpen = false;
        
        console.log('[TemplateManager] Constructor initialized');
    }
    
    // ✅ FIX: Template Manager initialisieren OHNE UI zu öffnen
    init() {
        try {
            // ✅ FIX: Sicherstellen dass ALLE Modals geschlossen sind
            this.forceCloseAllModals();
            
            this.setupEventListeners();
            this.setupCategoryFilters();
            this.setupUrlInputHandlers();
            this.isInitialized = true;
            
            // ✅ FIX: Explizit KEINE UI öffnen bei Init
            this.preventAutoOpen = true;
            this.allowedToOpen = false;
            
            console.log('[TemplateManager] Successfully initialized');
        } catch (error) {
            console.error('[TemplateManager] Initialization failed:', error);
            this.showError('Template Manager konnte nicht initialisiert werden', error);
        }
    }
    
    // ✅ FIX: Alle Modals zwangsweise schließen VERSTÄRKT
    forceCloseAllModals() {
        console.log('[TemplateManager] Force closing all modals...');
        
        // ✅ FIX: Body Classes entfernen
        document.body.classList.remove('nui-modal-open', 'nui-focus-active');
        
        // ✅ FIX: Alle Modal-Elemente verstecken
        const modals = [
            'template-selector',
            'url-input-modal', 
            'spray-editor',
            'error-modal',
            'loading-overlay',
            'performance-overlay',
            'notification'
        ];
        
        modals.forEach(modalId => {
            const modal = document.getElementById(modalId);
            if (modal) {
                modal.classList.add('hidden');
                modal.style.display = 'none !important'; // ✅ FIX: Explicit !important
                modal.style.visibility = 'hidden !important';
                modal.style.opacity = '0 !important';
                modal.style.pointerEvents = 'none !important';
                modal.style.zIndex = '-9999'; // ✅ FIX: Unter alles andere
                console.log(`[TemplateManager] Forced close: ${modalId}`);
            }
        });
        
        // ✅ FIX: Alle Overlays entfernen
        document.querySelectorAll('.modal, .overlay, .performance-overlay, .notification').forEach(element => {
            element.classList.add('hidden');
            element.style.display = 'none !important';
            element.style.visibility = 'hidden !important';
            element.style.opacity = '0 !important';
            element.style.pointerEvents = 'none !important';
            element.style.zIndex = '-9999';
        });
        
        // ✅ FIX: State zurücksetzen
        this.selectedTemplate = null;
        this.allowedToOpen = false;
        
        console.log('[TemplateManager] All modals force closed');
    }
    
    // ✅ FIX: Event Listeners einrichten OHNE Auto-Open
    setupEventListeners() {
        // Template Selector Events - NUR wenn erlaubt
        document.addEventListener('click', (e) => {
            // ✅ FIX: Prüfen ob UI-Interaktion erlaubt ist
            if (!this.allowedToOpen) {
                console.log('[TemplateManager] UI interaction blocked - not allowed to open');
                return;
            }
            
            // Template Item Click
            if (e.target.closest('.template-item')) {
                const templateItem = e.target.closest('.template-item');
                const templateId = templateItem.dataset.templateId;
                this.selectTemplateById(templateId);
            }
            
            // Category Button Click
            if (e.target.classList.contains('category-btn')) {
                const category = e.target.dataset.category;
                this.filterByCategory(category);
            }
            
            // Use Template Button
            if (e.target.id === 'use-template-btn') {
                this.useSelectedTemplate();
            }
        });
        
        // ESC Key Handler für Modals
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                // ✅ FIX: Immer schließen wenn ESC gedrückt wird
                this.forceCloseAllModals();
                
                // ✅ FIX: FiveM mitteilen dass alles geschlossen wurde
                this.sendCloseCallback();
            }
        });
        
        console.log('[TemplateManager] Event listeners attached');
    }
    
    // ✅ FIX: Category Filter Setup
    setupCategoryFilters() {
        const categoryButtons = document.querySelectorAll('.category-btn');
        categoryButtons.forEach(btn => {
            btn.addEventListener('click', (e) => {
                if (this.allowedToOpen) {
                    const category = e.target.dataset.category;
                    this.filterByCategory(category);
                }
            });
        });
        
        console.log('[TemplateManager] Category filter handlers attached');
    }
    
    // ✅ FIX: URL Input Handlers OHNE Auto-Open
    setupUrlInputHandlers() {
        // URL Input Field
        const urlInput = document.getElementById('image-url');
        if (urlInput) {
            urlInput.addEventListener('input', this.debounce(() => {
                if (this.allowedToOpen) {
                    this.validateUrlInput();
                }
            }, 500));
            
            urlInput.addEventListener('paste', (e) => {
                if (this.allowedToOpen) {
                    setTimeout(() => {
                        this.validateUrlInput();
                    }, 100);
                }
            });
        }
        
        // Preview Button
        const previewBtn = document.querySelector('[onclick="previewUrl()"]');
        if (previewBtn) {
            previewBtn.addEventListener('click', (e) => {
                e.preventDefault();
                if (this.allowedToOpen) {
                    this.previewUrl();
                }
            });
        }
        
        // Use URL Button
        const useUrlBtn = document.getElementById('use-url-btn');
        if (useUrlBtn) {
            useUrlBtn.addEventListener('click', (e) => {
                e.preventDefault();
                if (this.allowedToOpen) {
                    this.useUrlImage();
                }
            });
        }
        
        console.log('[TemplateManager] URL input handlers attached');
    }
    
    // ✅ FIX: Templates laden OHNE UI zu öffnen
    loadTemplates(templates, gang, grade) {
        console.log('[TemplateManager] Loading templates:', {
            count: templates ? templates.length : 0,
            gang: gang,
            grade: grade
        });
        
        this.templates = templates || [];
        this.currentGang = gang;
        this.currentGrade = grade || 0;
        this.selectedTemplate = null;
        
        // ✅ FIX: NUR Daten laden, KEINE UI öffnen
        this.templates.sort((a, b) => {
            if (a.available && !b.available) return -1;
            if (!a.available && b.available) return 1;
            
            const priorityA = a.priority || 999;
            const priorityB = b.priority || 999;
            if (priorityA !== priorityB) return priorityA - priorityB;
            
            return a.name.localeCompare(b.name);
        });
        
        // ✅ FIX: Daten vorbereiten aber NICHT anzeigen
        this.filterByCategory('all');
        
        console.log('[TemplateManager] Templates loaded (UI remains closed)');
    }
    
    // ✅ FIX: Template Selector SICHER öffnen
    openTemplateSelector(templates, gang, grade) {
        console.log('[TemplateManager] Attempting to open template selector...');
        
        // ✅ FIX: Erst alle Modals schließen
        this.forceCloseAllModals();
        
        // ✅ FIX: Erlaubnis zum Öffnen setzen
        this.allowedToOpen = true;
        this.preventAutoOpen = false;
        
        // ✅ FIX: Templates laden
        this.loadTemplates(templates, gang, grade);
        
        // ✅ FIX: Body Class setzen
        document.body.classList.add('nui-modal-open');
        
        // ✅ FIX: Modal anzeigen
        const templateModal = document.getElementById('template-selector');
        if (templateModal) {
            templateModal.classList.remove('hidden');
            templateModal.style.display = 'flex'; // ✅ FIX: Explicit display
            
            // ✅ FIX: Template Grid rendern
            this.renderTemplateGrid();
            this.updateUseTemplateButton();
            
            console.log('[TemplateManager] Template selector opened successfully');
        } else {
            console.error('[TemplateManager] Template selector modal not found');
            this.forceCloseAllModals();
        }
    }
    
    // ✅ FIX: URL Input SICHER öffnen
    openUrlInput(gang) {
        console.log('[TemplateManager] Attempting to open URL input...');
        
        // ✅ FIX: Erst alle Modals schließen
        this.forceCloseAllModals();
        
        // ✅ FIX: Erlaubnis zum Öffnen setzen
        this.allowedToOpen = true;
        this.preventAutoOpen = false;
        this.currentGang = gang;
        
        // ✅ FIX: Body Class setzen
        document.body.classList.add('nui-modal-open');
        
        // ✅ FIX: Modal anzeigen
        const urlModal = document.getElementById('url-input-modal');
        if (urlModal) {
            urlModal.classList.remove('hidden');
            urlModal.style.display = 'flex'; // ✅ FIX: Explicit display
            
            console.log('[TemplateManager] URL input opened successfully');
        } else {
            console.error('[TemplateManager] URL input modal not found');
            this.forceCloseAllModals();
        }
    }
    
    // ✅ FIX: Category Filter
    filterByCategory(category) {
        this.currentCategory = category;
        
        if (category === 'all') {
            this.filteredTemplates = [...this.templates];
        } else {
            this.filteredTemplates = this.templates.filter(template => 
                template.category === category
            );
        }
        
        // Category Buttons aktualisieren - nur wenn UI offen
        if (this.allowedToOpen) {
            this.updateCategoryButtons(category);
            this.renderTemplateGrid(this.filteredTemplates);
        }
        
        console.log('[TemplateManager] Filtered by category:', category, 'Count:', this.filteredTemplates.length);
    }
    
    // ✅ FIX: Category Buttons aktualisieren
    updateCategoryButtons(activeCategory) {
        const categoryButtons = document.querySelectorAll('.category-btn');
        categoryButtons.forEach(btn => {
            btn.classList.remove('active');
            if (btn.dataset.category === activeCategory) {
                btn.classList.add('active');
            }
        });
    }
    
    // ✅ FIX: Template Grid rendern
    renderTemplateGrid(filteredTemplates) {
        // ✅ FIX: Nur rendern wenn erlaubt
        if (!this.allowedToOpen) {
            console.log('[TemplateManager] Grid rendering blocked - not allowed');
            return;
        }
        
        const container = document.getElementById('template-grid');
        if (!container) {
            console.error('[TemplateManager] Template grid container not found');
            return;
        }
        
        const templatesToRender = filteredTemplates || this.templates;
        container.innerHTML = '';
        
        if (templatesToRender.length === 0) {
            container.innerHTML = this.createNoTemplatesMessage();
            return;
        }
        
        templatesToRender.forEach((template, index) => {
            const templateElement = this.createTemplateElement(template, index);
            container.appendChild(templateElement);
        });
        
        console.log('[TemplateManager] Template grid rendered with', templatesToRender.length, 'templates');
    }
    
    // Template Element erstellen
    createTemplateElement(template, index) {
        const element = document.createElement('div');
        element.className = 'template-item';
        element.dataset.templateId = template.id;
        element.dataset.category = template.category;
        
        const isAvailable = this.isTemplateAvailable(template);
        if (!isAvailable) {
            element.classList.add('locked');
        }
        
        if (this.selectedTemplate && this.selectedTemplate.id === template.id) {
            element.classList.add('selected');
        }
        
        element.innerHTML = this.getTemplateElementHTML(template, isAvailable);
        
        // Click Event mit verbesserter Logic
        if (isAvailable) {
            element.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                this.selectTemplate(template);
            });
        } else {
            element.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                this.showNotification(`Benötigt Gang-Rang ${template.requiredGrade} oder höher`, 'warning');
            });
        }
        
        // Lazy Loading für Performance
        if (index >= this.lazyLoadThreshold) {
            this.setupLazyLoading(element, template);
        }
        
        return element;
    }
    
    // Template Element HTML
    getTemplateElementHTML(template, isAvailable) {
        const imageUrl = this.getTemplateImageUrl(template);
        const categoryName = this.getCategoryDisplayName(template.category);
        const lockIcon = !isAvailable ? '<div class="template-lock"><i class="fas fa-lock"></i></div>' : '';
        const gradeRequirement = template.requiredGrade > 0 ? `<div class="template-grade">Rang ${template.requiredGrade}+</div>` : '';
        
        return `
            <div class="template-image">
                <img src="${imageUrl}" 
                     alt="${template.name}"
                     onerror="this.src='html/presets/default.png'"
                     loading="lazy">
                ${lockIcon}
            </div>
            <div class="template-name">${template.name}</div>
            <div class="template-category">${categoryName}</div>
            ${gradeRequirement}
        `;
    }
    
    // Template verfügbar prüfen
    isTemplateAvailable(template) {
        // Public Templates sind immer verfügbar
        if (template.isPublic) {
            return true;
        }
        
        // Gang Templates prüfen
        if (template.requiredGang && template.requiredGang !== this.currentGang) {
            return false;
        }
        
        // Grade Requirement prüfen
        if (template.requiredGrade && this.currentGrade < template.requiredGrade) {
            return false;
        }
        
        return true;
    }
    
    // Template auswählen
    selectTemplate(template) {
        if (!template || !this.isTemplateAvailable(template)) {
            console.warn('[TemplateManager] Cannot select unavailable template:', template);
            return;
        }
        
        // Previous selection entfernen
        if (this.selectedTemplate) {
            const prevElement = document.querySelector(`[data-template-id="${this.selectedTemplate.id}"]`);
            if (prevElement) {
                prevElement.classList.remove('selected');
            }
        }
        
        // Neue Selection setzen
        this.selectedTemplate = template;
        
        // Visual Selection
        const element = document.querySelector(`[data-template-id="${template.id}"]`);
        if (element) {
            element.classList.add('selected');
        }
        
        // Use Button aktivieren
        this.updateUseTemplateButton();
        
        console.log('[TemplateManager] Template selected:', template.id);
        this.showNotification(`Template "${template.name}" ausgewählt`, 'info');
    }
    
    // Template by ID auswählen
    selectTemplateById(templateId) {
        const template = this.templates.find(t => t.id === templateId);
        if (template) {
            this.selectTemplate(template);
        } else {
            console.warn('[TemplateManager] Template not found:', templateId);
        }
    }
    
    // Use Template Button aktualisieren
    updateUseTemplateButton() {
        const useBtn = document.getElementById('use-template-btn');
        if (!useBtn) return;
        
        if (this.selectedTemplate && this.isTemplateAvailable(this.selectedTemplate)) {
            useBtn.disabled = false;
            useBtn.textContent = `Template verwenden`;
        } else {
            useBtn.disabled = true;
            useBtn.textContent = 'Template auswählen';
        }
    }
    
    // Selected Template verwenden
    useSelectedTemplate() {
        if (!this.selectedTemplate) {
            this.showNotification('Bitte wähle zuerst ein Template aus', 'warning');
            return;
        }
        
        if (!this.isTemplateAvailable(this.selectedTemplate)) {
            this.showNotification('Template nicht verfügbar', 'error');
            return;
        }
        
        try {
            // Template Data für FiveM vorbereiten
            const templateData = {
                templateId: this.selectedTemplate.id,
                templateName: this.selectedTemplate.name,
                templatePath: this.selectedTemplate.filePath,
                category: this.selectedTemplate.category,
                gang: this.currentGang,
                isPublic: this.selectedTemplate.isPublic
            };
            
            // NUI Callback an FiveM Client
            fetch(`https://${this.getResourceName()}/useTemplate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(templateData)
            }).then(response => {
                if (response.ok) {
                    console.log('[TemplateManager] Template sent to client');
                    this.showNotification(`Template "${this.selectedTemplate.name}" wird verwendet`, 'success');
                    this.closeTemplateSelector();
                } else {
                    throw new Error('Server response not ok');
                }
            }).catch(error => {
                console.error('[TemplateManager] Failed to use template:', error);
                this.showError('Fehler beim Verwenden des Templates', error);
            });
            
        } catch (error) {
            console.error('[TemplateManager] Template usage error:', error);
            this.showError('Fehler beim Verwenden des Templates', error);
        }
    }
    
    // URL Input Validation
    validateUrlInput() {
        const urlInput = document.getElementById('image-url');
        const previewBtn = document.querySelector('[onclick="previewUrl()"]');
        
        if (!urlInput || !previewBtn) return;
        
        const url = urlInput.value.trim();
        
        if (url === '') {
            previewBtn.disabled = true;
            this.clearUrlPreview();
            return;
        }
        
        // URL Format validieren
        const isValidUrl = this.isValidImageUrl(url);
        previewBtn.disabled = !isValidUrl;
        
        if (!isValidUrl && url.length > 10) {
            this.showUrlError('Ungültige URL oder nicht unterstütztes Bildformat');
        } else {
            this.clearUrlError();
        }
    }
    
    // URL Preview
    previewUrl() {
        const urlInput = document.getElementById('image-url');
        if (!urlInput) return;
        
        const url = urlInput.value.trim();
        if (!url || !this.isValidImageUrl(url)) {
            this.showUrlError('Ungültige URL');
            return;
        }
        
        // Loading State
        this.setUrlLoadingState(true);
        this.clearUrlError();
        
        // Cache Check
        if (this.urlPreviewCache.has(url)) {
            const cachedData = this.urlPreviewCache.get(url);
            this.displayUrlPreview(cachedData.blob, cachedData.info);
            this.setUrlLoadingState(false);
            return;
        }
        
        // Image laden mit Timeout
        const img = new Image();
        const loadTimeout = setTimeout(() => {
            this.showUrlError('Timeout beim Laden des Bildes');
            this.setUrlLoadingState(false);
        }, this.imageLoadTimeout);
        
        img.onload = () => {
            clearTimeout(loadTimeout);
            
            // Image Info sammeln
            const imageInfo = {
                width: img.naturalWidth,
                height: img.naturalHeight,
                url: url,
                size: 'Unbekannt'
            };
            
            // Canvas für Base64 Conversion
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            canvas.width = img.naturalWidth;
            canvas.height = img.naturalHeight;
            ctx.drawImage(img, 0, 0);
            
            // Base64 Data
            canvas.toBlob((blob) => {
                if (blob) {
                    // Cache speichern
                    this.cacheUrlPreview(url, blob, imageInfo);
                    
                    // Preview anzeigen
                    this.displayUrlPreview(blob, imageInfo);
                } else {
                    this.showUrlError('Fehler beim Verarbeiten des Bildes');
                }
                
                this.setUrlLoadingState(false);
            }, 'image/png', 0.9);
        };
        
        img.onerror = () => {
            clearTimeout(loadTimeout);
            this.showUrlError('Bild konnte nicht geladen werden');
            this.setUrlLoadingState(false);
        };
        
        // CORS Proxy für externe URLs
        const proxyUrl = this.shouldUseProxy(url) ? `http://localhost:8080/proxy?url=${encodeURIComponent(url)}` : url;
        img.crossOrigin = 'anonymous';
        img.src = proxyUrl;
    }
    
    // URL Preview anzeigen
    displayUrlPreview(blob, imageInfo) {
        const previewContainer = document.getElementById('url-preview');
        const previewImage = document.getElementById('preview-image');
        const previewInfo = document.getElementById('preview-info');
        const dimensionsSpan = document.getElementById('image-dimensions');
        const sizeSpan = document.getElementById('image-size');
        const useUrlBtn = document.getElementById('use-url-btn');
        
        if (!previewContainer || !previewImage) return;
        
        // Image URL erstellen
        const imageUrl = URL.createObjectURL(blob);
        
        // Preview Image setzen
        previewImage.src = imageUrl;
        previewImage.classList.remove('hidden');
        
        // Info anzeigen
        if (dimensionsSpan) {
            dimensionsSpan.textContent = `${imageInfo.width} × ${imageInfo.height}px`;
        }
        
        if (sizeSpan) {
            const sizeKB = Math.round(blob.size / 1024);
            sizeSpan.textContent = `${sizeKB} KB`;
        }
        
        if (previewInfo) {
            previewInfo.classList.remove('hidden');
        }
        
        // Use Button aktivieren
        if (useUrlBtn) {
            useUrlBtn.disabled = false;
        }
        
        console.log('[TemplateManager] URL preview displayed:', imageInfo);
    }
    
    // URL Image verwenden
    useUrlImage() {
        const urlInput = document.getElementById('image-url');
        const previewImage = document.getElementById('preview-image');
        
        if (!urlInput || !previewImage || previewImage.classList.contains('hidden')) {
            this.showNotification('Bitte lade zuerst eine Vorschau', 'warning');
            return;
        }
        
        const url = urlInput.value.trim();
        
        try {
            // URL Data für FiveM vorbereiten
            const urlData = {
                imageUrl: url,
                imageData: previewImage.src, // Base64 Data URL
                gang: this.currentGang,
                source: 'url'
            };
            
            // NUI Callback an FiveM Client
            fetch(`https://${this.getResourceName()}/useUrlImage`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(urlData)
            }).then(response => {
                if (response.ok) {
                    console.log('[TemplateManager] URL image sent to client');
                    this.showNotification('URL-Bild wird verwendet', 'success');
                    this.closeUrlInput();
                } else {
                    throw new Error('Server response not ok');
                }
            }).catch(error => {
                console.error('[TemplateManager] Failed to use URL image:', error);
                this.showError('Fehler beim Verwenden des URL-Bildes', error);
            });
            
        } catch (error) {
            console.error('[TemplateManager] URL image usage error:', error);
            this.showError('Fehler beim Verwenden des URL-Bildes', error);
        }
    }
    
    // ✅ FIX: Template Selector SICHER schließen
    closeTemplateSelector() {
        console.log('[TemplateManager] Closing template selector...');
        
        const modal = document.getElementById('template-selector');
        if (modal) {
            modal.classList.add('hidden');
            modal.style.display = 'none'; // ✅ FIX: Explicit display none
        }
        
        // ✅ FIX: Body Class Cleanup
        document.body.classList.remove('nui-modal-open', 'nui-focus-active');
        
        // ✅ FIX: State zurücksetzen
        this.selectedTemplate = null;
        this.allowedToOpen = false;
        this.preventAutoOpen = true;
        
        this.updateUseTemplateButton();
        this.sendCloseCallback();
        
        console.log('[TemplateManager] Template selector closed');
    }
    
    // ✅ FIX: URL Input SICHER schließen
    closeUrlInput() {
        console.log('[TemplateManager] Closing URL input...');
        
        const modal = document.getElementById('url-input-modal');
        if (modal) {
            modal.classList.add('hidden');
            modal.style.display = 'none'; // ✅ FIX: Explicit display none
        }
        
        // ✅ FIX: Body Class Cleanup
        document.body.classList.remove('nui-modal-open', 'nui-focus-active');
        
        // ✅ FIX: State zurücksetzen
        this.allowedToOpen = false;
        this.preventAutoOpen = true;
        
        // Input und Preview zurücksetzen
        this.clearUrlInput();
        this.clearUrlPreview();
        
        this.sendCloseCallback();
        
        console.log('[TemplateManager] URL input closed');
    }
    
    // ✅ FIX: Sichere Close Callback Funktion
    sendCloseCallback() {
        try {
            fetch(`https://${this.getResourceName()}/closeNUI`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ action: 'close' })
            }).catch(error => {
                console.log('[TemplateManager] Close callback failed (expected in browser):', error);
            });
        } catch (error) {
            console.log('[TemplateManager] Close callback error (expected in browser):', error);
        }
    }
    
    // ✅ UTILITY FUNCTIONS
    
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    getTemplateImageUrl(template) {
        const resourceName = this.getResourceName();
        const basePaths = [
            `nui://${resourceName}/${template.filePath}`,
            `nui://${resourceName}/html/presets/${template.id}.png`,
            `html/presets/${template.id}.png`,
            'html/presets/default.png' // Fallback
        ];
        
        return basePaths[0];
    }
    
    getCategoryDisplayName(category) {
        const displayNames = {
            'all': 'Alle',
            'logo': 'Logos',
            'territory': 'Territory',
            'warning': 'Warnungen', 
            'tag': 'Tags',
            'unity': 'Einheit',
            'power': 'Macht',
            'public': 'Öffentlich',
            'gang': 'Gang',
            'global': 'Global'
        };
        
        return displayNames[category] || category;
    }
    
    isValidImageUrl(url) {
        try {
            const urlObj = new URL(url);
            const supportedFormats = ['.png', '.jpg', '.jpeg', '.webp', '.gif'];
            const supportedHosts = ['imgur.com', 'i.imgur.com', 'cdn.discordapp.com', 'media.discordapp.net'];
            
            // Format Check
            const hasValidFormat = supportedFormats.some(format => 
                urlObj.pathname.toLowerCase().includes(format)
            );
            
            // Host Check
            const hasValidHost = supportedHosts.some(host => 
                urlObj.hostname.includes(host)
            );
            
            return hasValidFormat && (hasValidHost || urlObj.protocol === 'https:');
        } catch {
            return false;
        }
    }
    
    shouldUseProxy(url) {
        try {
            const urlObj = new URL(url);
            // Verwende Proxy für externe Domains
            return !urlObj.hostname.includes('localhost') && !urlObj.hostname.includes('127.0.0.1');
        } catch {
            return false;
        }
    }
    
    cacheUrlPreview(url, blob, info) {
        // Cache Size Limit
        if (this.urlPreviewCache.size >= this.maxCacheSize) {
            const firstKey = this.urlPreviewCache.keys().next().value;
            this.urlPreviewCache.delete(firstKey);
        }
        
        this.urlPreviewCache.set(url, { blob, info, timestamp: Date.now() });
    }
    
    setUrlLoadingState(loading) {
        this.isLoadingUrl = loading;
        
        const previewBtn = document.querySelector('[onclick="previewUrl()"]');
        const loadingOverlay = document.getElementById('loading-overlay');
        
        if (previewBtn) {
            previewBtn.disabled = loading;
            previewBtn.innerHTML = loading ? 
                '<i class="fas fa-spinner fa-spin"></i> Lädt...' : 
                '<i class="fas fa-eye"></i> Vorschau';
        }
        
        if (loadingOverlay) {
            if (loading) {
                loadingOverlay.classList.remove('hidden');
            } else {
                loadingOverlay.classList.add('hidden');
            }
        }
    }
    
    clearUrlInput() {
        const urlInput = document.getElementById('image-url');
        if (urlInput) {
            urlInput.value = '';
        }
        
        const useUrlBtn = document.getElementById('use-url-btn');
        if (useUrlBtn) {
            useUrlBtn.disabled = true;
        }
        
        this.clearUrlError();
    }
    
    clearUrlPreview() {
        const previewImage = document.getElementById('preview-image');
        const previewInfo = document.getElementById('preview-info');
        
        if (previewImage) {
            // URL Object freigeben
            if (previewImage.src && previewImage.src.startsWith('blob:')) {
                URL.revokeObjectURL(previewImage.src);
            }
            previewImage.src = '';
            previewImage.classList.add('hidden');
        }
        
        if (previewInfo) {
            previewInfo.classList.add('hidden');
        }
    }
    
    showUrlError(message) {
        // Simple Error Display
        const urlInput = document.getElementById('image-url');
        if (urlInput) {
            urlInput.style.borderColor = '#ef4444';
            urlInput.title = message;
        }
        
        this.showNotification(message, 'error');
    }
    
    clearUrlError() {
        const urlInput = document.getElementById('image-url');
        if (urlInput) {
            urlInput.style.borderColor = '';
            urlInput.title = '';
        }
    }
    
    createNoTemplatesMessage() {
        return `
            <div class="no-templates">
                <i class="fas fa-images"></i>
                <p>Keine Templates verfügbar</p>
                <small>Wähle eine andere Kategorie oder kontaktiere einen Administrator</small>
            </div>
        `;
    }
    
    setupLazyLoading(element, template) {
        const img = element.querySelector('img');
        if (!img) return;
        
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const actualSrc = this.getTemplateImageUrl(template);
                    img.src = actualSrc;
                    observer.unobserve(element);
                }
            });
        });
        
        observer.observe(element);
    }
    
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
        
        console.log(`[TemplateManager] Notification (${type}):`, message);
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
        
        console.error('[TemplateManager] Error:', message, error);
    }
}

// ✅ FIX: Global Functions für HTML Events - mit Sicherheitsprüfung
function previewUrl() {
    if (window.templateManager && window.templateManager.allowedToOpen) {
        window.templateManager.previewUrl();
    }
}

function useUrlImage() {
    if (window.templateManager && window.templateManager.allowedToOpen) {
        window.templateManager.useUrlImage();
    }
}

function useSelectedTemplate() {
    if (window.templateManager && window.templateManager.allowedToOpen) {
        window.templateManager.useSelectedTemplate();
    }
}

function closeTemplateSelector() {
    if (window.templateManager) {
        window.templateManager.closeTemplateSelector();
    }
}

function closeUrlInput() {
    if (window.templateManager) {
        window.templateManager.closeUrlInput();
    }
}

// ✅ FIX: NUI Message Handler - SICHERE Version
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'openTemplateSelector':
            console.log('[TemplateManager] Opening template selector via NUI message');
            
            if (!window.templateManager) {
                window.templateManager = new TemplateManager();
                window.templateManager.init();
            }
            
            // ✅ FIX: SICHERE Öffnung über spezielle Funktion
            window.templateManager.openTemplateSelector(data.templates, data.gang, data.grade);
            break;
            
        case 'openUrlInput':
            console.log('[TemplateManager] Opening URL input via NUI message');
            
            if (!window.templateManager) {
                window.templateManager = new TemplateManager();
                window.templateManager.init();
            }
            
            // ✅ FIX: SICHERE Öffnung über spezielle Funktion
            window.templateManager.openUrlInput(data.gang);
            break;
            
        case 'closeTemplateSelector':
        case 'closeUrlInput':
        case 'closeAll':
            console.log('[TemplateManager] Closing UI via NUI message');
            
            if (window.templateManager) {
                window.templateManager.forceCloseAllModals();
            }
            break;
    }
});

// ✅ FIX: DOM Ready Handler - ABSOLUT SICHER OHNE Auto-Open
document.addEventListener('DOMContentLoaded', function() {
    console.log('[TemplateManager] DOM loaded, creating global instance');
    
    // ✅ FIX: ERSTE PRIORITÄT - Alle UI-Elemente sofort verstecken
    const uiElements = [
        'template-selector',
        'url-input-modal', 
        'spray-editor',
        'error-modal',
        'loading-overlay',
        'performance-overlay',
        'notification'
    ];
    
    uiElements.forEach(elementId => {
        const element = document.getElementById(elementId);
        if (element) {
            element.classList.add('hidden');
            element.style.display = 'none';
            element.style.visibility = 'hidden';
            element.style.opacity = '0';
            element.style.pointerEvents = 'none';
            console.log(`[TemplateManager] Force hidden: ${elementId}`);
        }
    });
    
    // ✅ FIX: Body Class Cleanup
    document.body.classList.remove('nui-modal-open', 'nui-focus-active');
    
    // ✅ FIX: Alle Overlays verstecken
    document.querySelectorAll('.modal, .overlay, .performance-overlay').forEach(element => {
        element.classList.add('hidden');
        element.style.display = 'none';
        element.style.visibility = 'hidden';
        element.style.opacity = '0';
        element.style.pointerEvents = 'none';
    });
    
    // Global Template Manager Instance erstellen
    if (!window.templateManager) {
        window.templateManager = new TemplateManager();
        window.templateManager.init();
    }
    
    console.log('[TemplateManager] Initialization complete - UI remains closed');
});

// ✅ FIX: Window Load Handler - DOPPELTE SICHERHEIT
window.addEventListener('load', function() {
    // ✅ FIX: Nochmals alle UI-Elemente verstecken
    const allModals = document.querySelectorAll('.modal, #spray-editor, .overlay, .performance-overlay');
    allModals.forEach(modal => {
        modal.classList.add('hidden');
        modal.style.display = 'none';
        modal.style.visibility = 'hidden';
        modal.style.opacity = '0';
        modal.style.pointerEvents = 'none';
    });
    
    // Body Class erneut bereinigen
    document.body.classList.remove('nui-modal-open', 'nui-focus-active');
    
    if (!window.templateManager) {
        console.log('[TemplateManager] Creating template manager on window load');
        window.templateManager = new TemplateManager();
        window.templateManager.init();
    }
    
    // ✅ FIX: Sicherstellen dass nichts offen ist
    if (window.templateManager) {
        window.templateManager.forceCloseAllModals();
    }
    
    console.log('[TemplateManager] Window load complete - All UI forced hidden');
});

console.log('[TemplateManager] Script loaded successfully');